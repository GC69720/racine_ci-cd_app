#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <env> <action>"
  echo "  env    : dev1 | recette | preprod | prod"
  echo "  action : start | stop | restart_from_scratch"
  exit 1
}

ENV_NAME="${1:-}"; ACTION="${2:-}"
[[ -z "${ENV_NAME}" || -z "${ACTION}" ]] && usage

case "${ENV_NAME}" in
  dev1|recette|preprod|prod) ;;
  *) echo "Environnement invalide: ${ENV_NAME}"; usage ;;
esac

ENV_FILE="envs/${ENV_NAME}.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Fichier env manquant: ${ENV_FILE}"; exit 2
fi
# shellcheck disable=SC1090
source "${ENV_FILE}"

require_podman() {
  if ! command -v podman >/dev/null 2>&1; then
    echo "Podman n'est pas installé."; exit 3
  fi
}

has_machine_cmd() {
  podman machine list >/dev/null 2>&1
}

list_machine_names() {
  # Retourne la liste des noms (un par ligne), sans astérisque ni CR
  if podman machine list --format '{{.Name}}' >/dev/null 2>&1; then
    podman machine list --format '{{.Name}}' | tr -d '*\r'
  else
    # Fallback: parse le tableau et enlève un éventuel '*'
    podman machine list 2>/dev/null | awk 'NR>1{print $1}' | sed 's/\*$//' | tr -d '\r'
  fi
}

machine_exists() {
  list_machine_names | grep -xq "${PODMAN_MACHINE_NAME}"
}

machine_state() {
  local st
  st=$(podman machine inspect "${PODMAN_MACHINE_NAME}" --format '{{.State}}' 2>/dev/null || true)
  if [[ -n "${st}" ]]; then
    echo "${st}"
  else
    # Fallback via la table (colonne STATE)
    podman machine list 2>/dev/null | awk -v n="${PODMAN_MACHINE_NAME}" 'NR>1 && $1 ~ "^" n "(\*$)?$" {print $3}'
  fi
}

init_supports() {
  podman machine init --help 2>&1 | tr -d '\r' | grep -q -- "$1"
}

set_supports() {
  podman machine set --help >/dev/null 2>&1 && podman machine set --help 2>&1 | tr -d '\r' | grep -q -- "$1"
}

create_machine() {
  echo "Création de la VM Podman '${PODMAN_MACHINE_NAME}' (CPUs=${PODMAN_CPUS}, RAM=${PODMAN_MEMORY_MB}MB, DISK=${PODMAN_DISK_GB}GB)..."

  # Passage du nom: --name si dispo, sinon argument positionnel
  name_args=()
  if init_supports "--name"; then
    name_args=(--name "${PODMAN_MACHINE_NAME}")
  else
    name_args=("${PODMAN_MACHINE_NAME}")
  fi

  # Flags ressources sur init si supportés
  init_args=()
  init_has_any=0
  if init_supports "--cpus"; then init_args+=(--cpus "${PODMAN_CPUS}"); init_has_any=1; fi
  if init_supports "--memory"; then init_args+=(--memory "${PODMAN_MEMORY_MB}"); init_has_any=1; fi
  if init_supports "--disk-size"; then init_args+=(--disk-size "${PODMAN_DISK_GB}"); init_has_any=1; fi

  set_args=()
  set_has_any=0
  if set_supports "--cpus"; then set_args+=(--cpus "${PODMAN_CPUS}"); set_has_any=1; fi
  if set_supports "--memory"; then set_args+=(--memory "${PODMAN_MEMORY_MB}"); set_has_any=1; fi
  if set_supports "--disk-size"; then set_args+=(--disk-size "${PODMAN_DISK_GB}"); set_has_any=1; fi

  if [[ "${init_has_any}" -eq 1 ]]; then
    if podman machine init "${init_args[@]}" "${name_args[@]}"; then
      :
    else
      echo "Avertissement: 'podman machine init' a échoué avec les flags ressources. Re-tentative sans flags..."
      podman machine init "${name_args[@]}"
      if [[ "${set_has_any}" -eq 1 ]]; then
        podman machine set "${set_args[@]}" "${PODMAN_MACHINE_NAME}" || true
      fi
    fi
  else
    podman machine init "${name_args[@]}"
    if [[ "${set_has_any}" -eq 1 ]]; then
      podman machine set "${set_args[@]}" "${PODMAN_MACHINE_NAME}" || true
    fi
  fi

  podman machine start "${PODMAN_MACHINE_NAME}"
}

ensure_machine_running() {
  require_podman
  if has_machine_cmd; then
    if machine_exists; then
      local STATE
      STATE=$(machine_state)
      if [[ "${STATE}" != "Running" ]]; then
        echo "Démarrage de la VM Podman '${PODMAN_MACHINE_NAME}'..."
        podman machine start "${PODMAN_MACHINE_NAME}"
      fi
    else
      create_machine
    fi
  fi
}

recreate_machine() {
  require_podman
  if has_machine_cmd; then
    # Suppression préventive (même si la détection échoue), pour éviter "VM already exists"
    podman machine stop "${PODMAN_MACHINE_NAME}" || true
    podman machine rm -f "${PODMAN_MACHINE_NAME}" || true
    create_machine
  else
    echo "Podman Machine non détecté (Linux rootless ?). Réinitialisation du système Podman..."
    podman system reset -f || true
  fi
  ./scripts/install_certs.sh "${ENV_NAME}" || true
}

compose() {
  podman compose -f compose.yaml --env-file "${ENV_FILE}" "$@"
}

case "${ACTION}" in
  start)
    ensure_machine_running
    echo "Démarrage des services pour ${ENV_NAME}..."
    export ENV_NAME
    export COMPOSE_PROFILES
    compose up -d --build || { echo "Erreur au démarrage, affichage des logs..."; podman ps -a; podman logs backend || true; podman logs frontend || true; podman logs proxy || true; exit 5; }
    ;;
  stop)
    echo "Arrêt des services pour ${ENV_NAME}..."
    export ENV_NAME
    export COMPOSE_PROFILES
    compose down || true
    ;;
  restart_from_scratch)
    echo "Réinitialisation complète de l'environnement ${ENV_NAME}..."
    recreate_machine
    export ENV_NAME
    export COMPOSE_PROFILES
    compose down || true
    compose build
    compose up -d || { echo "Erreur au démarrage, affichage des logs..."; podman ps -a; podman logs backend || true; podman logs frontend || true; podman logs proxy || true; exit 6; }
    ;;
  *)
    usage
    ;;
esac

./scripts/smoke_test.sh "${ENV_NAME}" || true
