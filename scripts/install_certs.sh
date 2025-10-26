#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-dev1}"
CA_FILE="certs/${ENV_NAME}/ca.crt"

debug() { [ "${DEBUG:-0}" = "1" ] && echo "[DEBUG] $*"; }

if [[ -f "${CA_FILE}" ]]; then
  echo "Import du CA dans la VM Podman (si présente)..."
  if podman machine list >/dev/null 2>&1; then
    # Détecte le nom de VM (sans astérisque)
    if podman machine list --format '{{.Name}}' >/dev/null 2>&1; then
      DEFAULT_MACHINE="$(podman machine list --format '{{.Name}}' | head -n1 | tr -d '*\r\n')"
    else
      DEFAULT_MACHINE="$(podman machine list 2>/dev/null | awk 'NR==2{print $1}' | sed 's/\*$//' | tr -d '\r\n')"
    fi
    debug "VM: '${DEFAULT_MACHINE}'"

    if [[ -n "${DEFAULT_MACHINE}" ]]; then
      # 1) Store système
      echo "-> Store système (update-ca-trust)"
      podman machine ssh "${DEFAULT_MACHINE}" "sudo tee /etc/pki/ca-trust/source/anchors/racine-ci-cd-${ENV_NAME}.crt >/dev/null" < "${CA_FILE}"
      podman machine ssh "${DEFAULT_MACHINE}" "sudo update-ca-trust"

      # 2) Store containers/image (par registre)
      echo "-> Store containers/image (/etc/containers/certs.d)"
      # Charge variables d'env pour récupérer MITM_REGISTRY_HOSTS
      if [[ -f "envs/${ENV_NAME}.env" ]]; then
        set -a; source "envs/${ENV_NAME}.env"; set +a
      fi
      HOSTS_CSV="${MITM_REGISTRY_HOSTS:-docker.io,registry-1.docker.io,auth.docker.io}"
      IFS=',' read -r -a HOSTS <<< "${HOSTS_CSV}"
      for h in "${HOSTS[@]}"; do
        h="$(echo "$h" | xargs)"  # trim
        [[ -z "$h" ]] && continue
        echo "   - ${h}"
        podman machine ssh "${DEFAULT_MACHINE}" "sudo mkdir -p /etc/containers/certs.d/${h}"
        podman machine ssh "${DEFAULT_MACHINE}" "sudo tee /etc/containers/certs.d/${h}/ca.crt >/dev/null" < "${CA_FILE}"
      done

      # 3) Redémarrage de la VM pour que tout prenne effet proprement
      podman machine stop "${DEFAULT_MACHINE}" && podman machine start "${DEFAULT_MACHINE}"
      echo "CA importé (système + certs.d) et VM redémarrée."
    else
      echo "Impossible de détecter la VM Podman."
      exit 1
    fi
  else
    echo "Podman Machine non utilisé : importer le CA sur le host si nécessaire."
  fi
else
  echo "Aucun CA trouvé pour ${ENV_NAME} (${CA_FILE})."
fi
