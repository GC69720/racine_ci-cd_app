#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 {encrypt|decrypt|clean|status} <env>"
  echo "  env: dev1 | recette | preprod | prod"
  exit 1
}

cmd="${1:-}"; ENV_NAME="${2:-}"
[[ -z "${cmd}" || -z "${ENV_NAME}" ]] && usage

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="${ROOT}/certs/${ENV_NAME}"
ENC="${CERT_DIR}/tls.key.enc"
DEC="${CERT_DIR}/tls.key"
SOPS_CFG_DEFAULT="${ROOT}/.sops.yaml"
SOPS_CFG="${SOPS_CONFIG:-${SOPS_CFG_DEFAULT}}"
RECIP_FILE="${ROOT}/.age-recipients"

ensure_tools() { command -v sops >/dev/null || { echo "❌ sops introuvable"; exit 2; }; }
is_windows_exe() { command -v sops | grep -qiE '\.exe$'; }
to_winpath() { command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || printf '%s' "$1"; }

encrypt_with_config() {
  sops --config "${SOPS_CFG}" --encrypt --input-type binary --output-type binary "${DEC}" > "${ENC}"
}

encrypt_with_recipients_cfg_override() {
  local recipients=()
  if [[ -n "${SOPS_AGE_RECIPIENT:-}" ]]; then
    IFS=',' read -r -a arr <<< "${SOPS_AGE_RECIPIENT}"
    for r in "${arr[@]}"; do recipients+=("--age" "$(echo "$r" | xargs)"); done
  elif [[ -f "${RECIP_FILE}" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      recipients+=("--age" "$(echo "$line" | xargs)")
    done < "${RECIP_FILE}"
  else
    echo "❌ Aucun destinataire (SOPS_AGE_RECIPIENT vide et ${RECIP_FILE} absent)."; exit 4
  fi

  # config vide pour IGNORER .sops.yaml, avec conversion de chemin pour sops.exe
  local tmpcfg; tmpcfg="$(mktemp)"; printf 'creation_rules: []\n' > "${tmpcfg}"
  local cfg="${tmpcfg}"
  if is_windows_exe; then cfg="$(to_winpath "${tmpcfg}")"; fi

  SOPS_CONFIG="${cfg}" sops --encrypt "${recipients[@]}" --input-type binary --output-type binary "${DEC}" > "${ENC}"
  rm -f "${tmpcfg}"
}

encrypt_with_recipients_cfg_rename() {
  # Dernier recours: on met .sops.yaml de côté le temps d'une commande
  local moved=0 backup=""
  if [[ -f "${SOPS_CFG_DEFAULT}" ]]; then
    backup="${SOPS_CFG_DEFAULT}.off"
    mv -f "${SOPS_CFG_DEFAULT}" "${backup}"
    moved=1
  fi
  set +e
  encrypt_with_recipients_cfg_override
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    [[ $moved -eq 1 ]] && mv -f "${backup}" "${SOPS_CFG_DEFAULT}" || true
    return $rc
  fi
  [[ $moved -eq 1 ]] && mv -f "${backup}" "${SOPS_CFG_DEFAULT}" || true
}

encrypt_key() {
  ensure_tools
  mkdir -p "${CERT_DIR}"
  [[ -f "${DEC}" ]] || { echo "❌ Manquant: ${DEC}"; exit 3; }
  echo "🔐 Chiffrement -> ${ENC}"

  # 1) Essai avec .sops.yaml
  set +e
  encrypt_with_config
  local rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    :
  else
    echo "ℹ️  Pas de règle correspondante dans ${SOPS_CFG} (ou erreur). Tentative avec destinataires explicites…"
    # 2) Essai avec config vide (SOPS_CONFIG pointant vers un YAML vide)
    set +e
    encrypt_with_recipients_cfg_override
    rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
      echo "ℹ️  Nouvelle tentative en désactivant temporairement .sops.yaml…"
      encrypt_with_recipients_cfg_rename
    fi
  fi

  chmod 600 "${ENC}" || true
  rm -f "${DEC}"
  echo "✅ Fait. ${DEC} supprimée."
}

decrypt_key() {
  ensure_tools
  [[ -f "${ENC}" ]] || { echo "❌ Manquant: ${ENC}"; exit 5; }
  echo "🔓 Déchiffrement -> ${DEC}"
  sops --decrypt --input-type binary --output-type binary "${ENC}" > "${DEC}"
  chmod 600 "${DEC}" || true
  echo "✅ Fait. ${DEC} prête."
}

clean_plain() {
  if [[ -f "${DEC}" ]]; then
    echo "🧹 Suppression de la clé en clair: ${DEC}"
    rm -f "${DEC}"
  else
    echo "ℹ️  Rien à nettoyer."
  fi
}

status() {
  echo "📄 ${ENC}: $([[ -f "${ENC}" ]] && echo 'présent' || echo 'absent')"
  echo "🔑 ${DEC}: $([[ -f "${DEC}" ]] && echo 'présent (NE PAS COMMIT)' || echo 'absent')"
  echo "⚙️  SOPS_CONFIG: ${SOPS_CFG}"
  [[ -f "${RECIP_FILE}" ]] && echo "👥 Destinataires: $(grep -vcE '^\s*#|^\s*$' "${RECIP_FILE}") dans ${RECIP_FILE}" || true
}

case "${cmd}" in
  encrypt) encrypt_key ;;
  decrypt) decrypt_key ;;
  clean)   clean_plain ;;
  status)  status ;;
  *) usage ;;
esac
