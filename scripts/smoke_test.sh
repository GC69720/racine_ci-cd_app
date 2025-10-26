#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${1:-dev1}"
source "envs/${ENV_NAME}.env"

BASE_HTTPS="https://${APP_DOMAIN}:${PROXY_HTTPS_PORT}"
BASE_HTTP="http://localhost:${PROXY_HTTP_PORT}"

echo "== Tests fumée =="

echo "[1] Proxy + Frontend via HTTPS: ${BASE_HTTPS}/"
curl -k -I "${BASE_HTTPS}/" || echo "Échec (HTTPS)"

echo "[2] API health via HTTPS: ${BASE_HTTPS}/api/healthz"
curl -k "${BASE_HTTPS}/api/healthz" || echo "Échec (HTTPS API)"

echo "[3] Fallback HTTP local: ${BASE_HTTP}/ (si HTTPS indisponible)"
curl -I "${BASE_HTTP}/" || echo "Échec (HTTP)"

echo
echo "URLs à tester dans le navigateur :"
echo "  Frontend  : ${BASE_HTTPS}/"
echo "  API Health: ${BASE_HTTPS}/api/healthz"
