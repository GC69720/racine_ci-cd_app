# ===== Build stage =====
FROM node:20-alpine AS builder
ARG INCLUDE_CA=0
ARG ENV_NAME=dev1

# Ajouter CA pour npm/yarn si nécessaire
RUN apk add --no-cache ca-certificates
COPY certs/${ENV_NAME}/ca.crt /usr/local/share/ca-certificates/enterprise.crt
RUN if [ "$INCLUDE_CA" = "1" ] && [ -f /usr/local/share/ca-certificates/enterprise.crt ]; then \
      update-ca-certificates; \
    fi

WORKDIR /app
COPY frontend/package.json frontend/package-lock.json* frontend/pnpm-lock.yaml* frontend/yarn.lock* ./ 
RUN if [ -f package-lock.json ]; then npm ci; \
    elif [ -f pnpm-lock.yaml ]; then npm i -g pnpm && pnpm i --frozen-lockfile; \
    elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    else npm i; fi
COPY frontend/ ./
RUN npm run build

# ===== Serve stage =====
FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
