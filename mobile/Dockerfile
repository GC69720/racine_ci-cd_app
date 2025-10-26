FROM node:20-alpine
ARG INCLUDE_CA=0
ARG ENV_NAME=dev1

RUN apk add --no-cache ca-certificates
COPY certs/${ENV_NAME}/ca.crt /usr/local/share/ca-certificates/enterprise.crt
RUN if [ "$INCLUDE_CA" = "1" ] && [ -f /usr/local/share/ca-certificates/enterprise.crt ]; then \
      update-ca-certificates; \
    fi

WORKDIR /app
COPY mobile/package.json mobile/package-lock.json* ./
RUN npm ci || npm i
COPY mobile/ ./
EXPOSE 19000 19001 19002
CMD ["npm", "run", "start"]
