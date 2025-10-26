#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-dev1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/envs/${ENV_NAME}.env"
CA_FILE="${ROOT_DIR}/certs/${ENV_NAME}/ca.crt"

if [[ ! -f "${CA_FILE}" ]]; then
  echo "❌ CA introuvable: ${CA_FILE} (mets ton zscaler-bundle ici)"
  exit 1
fi

# Charge les variables pour récupérer MITM_REGISTRY_HOSTS
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

# Hosts par défaut + ceux fournis dans l'env
DEFAULT_HOSTS="docker.io,registry-1.docker.io,auth.docker.io,index.docker.io,cdn.auth.docker.io,production.cloudflare.docker.com"
HOSTS_CSV="${MITM_REGISTRY_HOSTS:-${DEFAULT_HOSTS}}"

# Détection nom de VM (sans *)
if podman machine list --format '{{.Name}}' >/dev/null 2>&1; then
  VM="$(podman machine list --format '{{.Name}}' | head -n1 | tr -d '*\r\n')"
else
  VM="$(podman machine list 2>/dev/null | awk 'NR==2{print $1}' | sed 's/\*$//' | tr -d '\r\n')"
fi
if [[ -z "${VM}" ]]; then
  echo "❌ Impossible de détecter la VM Podman"; exit 2
fi

echo "Import du CA dans la VM Podman '${VM}' (store système + certs.d)…"

# 1) Store système (update-ca-trust)
podman machine ssh "${VM}" "sudo tee /etc/pki/ca-trust/source/anchors/racine-ci-cd-${ENV_NAME}.crt >/dev/null" < "${CA_FILE}"
podman machine ssh "${VM}" "sudo update-ca-trust" || true

# 2) Store containers/image (certs.d) pour chaque host
IFS=',' read -r -a HOSTS <<< "${HOSTS_CSV}"
for h in "${HOSTS[@]}"; do
  h="$(echo "$h" | xargs)"
  [[ -z "$h" ]] && continue
  echo " - Déploiement CA pour ${h}"
  podman machine ssh "${VM}" "sudo mkdir -p /etc/containers/certs.d/${h}"
  podman machine ssh "${VM}" "sudo tee /etc/containers/certs.d/${h}/ca.crt >/dev/null" < "${CA_FILE}"
done

# 3) Vérifications de confiance (diagnostic)
echo "Vérifications TLS (openssl) :"
podman machine ssh "${VM}" 'for d in /etc/containers/certs.d/*; do h=$(basename "$d"); printf "   %s : " "$h"; \
  (timeout 6 openssl s_client -servername "$h" -connect "$h:443" -CAfile /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem < /dev/null 2>/dev/null | grep -q "Verify return code: 0 (ok)") && \
  echo "OK" || echo "FAIL"; done' || true

# 4) Redémarrage pour prise en compte globale
podman machine stop "${VM}" >/dev/null 2>&1 || true
podman machine start "${VM}" >/dev/null 2>&1 || true
echo "✅ CA installé & VM redémarrée."
