# ===== Build stage =====
FROM node:20-alpine AS builder

ARG INCLUDE_CA=0
ARG ENV_NAME=dev1

# (Optionnel) CA d'entreprise pour npm/yarn
RUN apk add --no-cache ca-certificates
# ⚠️ Le fichier doit exister dans le contexte ./frontend : ./frontend/certs/${ENV_NAME}/ca.crt
COPY certs/${ENV_NAME}/ca.crt /usr/local/share/ca-certificates/enterprise.crt
RUN if [ "$INCLUDE_CA" = "1" ] && [ -f /usr/local/share/ca-certificates/enterprise.crt ]; then \
      update-ca-certificates; \
    fi

WORKDIR /app

# Installe les deps avec fallback et contournement des conflits de peer deps
COPY package*.json ./
RUN if [ -f package-lock.json ]; then \
      npm ci --legacy-peer-deps; \
    else \
      npm install --legacy-peer-deps; \
    fi

# Copie du code et build (toujours relatif à ./frontend)
COPY . .
RUN npm run build

# ===== Runtime (nginx) =====
FROM nginx:1.27-alpine

# CRA = build/, Vite = dist/ — tu utilises dist/ ici
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
