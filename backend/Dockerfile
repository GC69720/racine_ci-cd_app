FROM python:3.11-slim

ARG INCLUDE_CA=0
ARG ENV_NAME=dev1

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# ⚠️ Avec context=./backend, ce fichier doit exister dans ./backend/certs/${ENV_NAME}/ca.crt
# (sinon enlève complètement ces 2 lignes ou fais les copier par ton script avant le build)
COPY certs/${ENV_NAME}/ca.crt /usr/local/share/ca-certificates/enterprise.crt
RUN if [ "$INCLUDE_CA" = "1" ] && [ -f /usr/local/share/ca-certificates/enterprise.crt ]; then \
      update-ca-certificates; \
    fi

WORKDIR /app

# Chemins relatifs au contexte ./backend
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
CMD ["/bin/bash", "-lc", "python manage.py migrate && gunicorn app.wsgi:application --bind 0.0.0.0:8000 --workers 3"]
