FROM python:3.11-slim

ARG INCLUDE_CA=0
ARG ENV_NAME=dev1

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# === Inject CA d'entreprise (optionnel) ===
# On copie S'IL EXISTE' le fichier certs/<env>/ca.crt dans l'image et on met à jour le store
# (La copie échoue si le fichier est absent; comme tu l'as créé, cela passera)
COPY certs/${ENV_NAME}/ca.crt /usr/local/share/ca-certificates/enterprise.crt
RUN if [ "$INCLUDE_CA" = "1" ] && [ -f /usr/local/share/ca-certificates/enterprise.crt ]; then \
      update-ca-certificates; \
    fi

WORKDIR /app

COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ /app/

# Entrypoint: wait for DB, run migrations, then gunicorn
CMD ["/bin/bash", "-lc", "python manage.py migrate && gunicorn app.wsgi:application --bind 0.0.0.0:8000 --workers 3"]
