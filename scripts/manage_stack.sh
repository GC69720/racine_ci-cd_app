#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-}"
ACTION="${2:-}"

usage() {
  echo "Usage: ./scripts/manage_stack.sh <env> <action>"
  echo "  env    : dev1 | recette | preprod | prod"
  echo "  action : build | start | stop | restart_from_scratch"
  exit 1
}

[[ -z "$ENV_NAME" || -z "$ACTION" ]] && usage
case "$ENV_NAME" in
  dev1|recette|preprod|prod) ;;
  *) usage ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/compose.yaml"
ENV_FILE="$ROOT_DIR/envs/${ENV_NAME}.env"

compose() {
  podman-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

ensure_ca_crt() {
  local target="$ROOT_DIR/certs/${ENV_NAME}/ca.crt"
  if [[ ! -f "$target" ]]; then
    echo "⚠️  $target introuvable. Tentative d’approvisionnement…"
    mkdir -p "$(dirname "$target")"
    if [[ -f "$ROOT_DIR/certs/zscaler-bundle.crt" ]]; then
      cp "$ROOT_DIR/certs/zscaler-bundle.crt" "$target"
      echo "✅ Copié certs/zscaler-bundle.crt -> certs/${ENV_NAME}/ca.crt"
    elif [[ -f "$ROOT_DIR/certs/zscaler-root.cer" ]]; then
      # Beaucoup de .cer Zscaler sont déjà PEM. On les duplique en .crt.
      cp "$ROOT_DIR/certs/zscaler-root.cer" "$target"
      echo "✅ Copié certs/zscaler-root.cer -> certs/${ENV_NAME}/ca.crt"
      echo "ℹ️  Si l’image échoue encore sur ce cert, il faudra peut-être convertir en PEM avec openssl."
    else
      echo "❌ Aucun bundle CA trouvé. Place un fichier à l’un de ces emplacements :"
      echo "   - certs/zscaler-bundle.crt  (recommandé)"
      echo "   - certs/zscaler-root.cer    (duplication en .crt)"
      exit 1
    fi
  fi
}

decrypt_tls() {
  # Si tu as déjà un script de secrets, on l’utilise; sinon on ignore silencieusement.
  if [[ -x "$ROOT_DIR/scripts/secrets.sh" ]]; then
    "$ROOT_DIR/scripts/secrets.sh" decrypt "$ENV_NAME" || true
  fi
}

case "$ACTION" in
  build)
    decrypt_tls
    ensure_ca_crt
    compose build
    ;;

  start)
    decrypt_tls
    ensure_ca_crt
    compose up -d
    ;;

  stop)
    compose down
    ;;

  restart_from_scratch)
    decrypt_tls
    ensure_ca_crt
    compose down -v --remove-orphans || true
    compose build --no-cache
    compose up -d
    ;;

  *)
    usage
    ;;
esac
