# racine_ci-cd_app — Template CI/CD DevSecOps (local-first, Podman)

Ce dépôt **template** fournit une base prête à l’emploi pour lancer en local (PC) un stack complet :
- **Proxy Nginx** (TLS auto-géré par vos certificats)
- **Backend Django (Python 3.11)** avec Postgres & Redis
- **Frontend React (Vite + Nginx)**
- **Tests fumée** automatiques après démarrage
- **Scripts** d'arrêt/démarrage/reconstruction **variabilisés par environnement** (dev1, recette, preprod, prod)
- **Pré-commit DevSecOps** (ruff, black, bandit, detect-secrets) + gabarits GitHub Actions

> **Objectif**: partir d’un **environnement CI/CD template** nommé `racine_ci-cd_app` pour développer ensuite des apps web / Android / iOS (Expo inclus en squelette) à haute performance.

---

## 0) Prérequis locaux

- Podman ≥ 4.x avec `podman compose` disponible
- (Windows/macOS) : Podman Machine activé
- Git, Python 3.11+, Node 18+ si vous préférez lancer les apps en dehors des conteneurs
- Ouvrir les ports **8080** (HTTP) et **8443** (HTTPS) localement

> **Astuce DNS locale**: le domaine par défaut est `app.localtest.me` (résout vers 127.0.0.1). Pas besoin de modifier `/etc/hosts`.

---

## 1) Démarrage rapide (en local)

```bash
# 1) Dézippez le projet puis placez-vous dans le dossier
cd racine_ci-cd_app

# 2) Copiez/validez la configuration de l’environnement (déjà prête pour dev1)
# (optionnel) ajustez les valeurs dans envs/dev1.env selon votre machine

# 3) Donnez les droits d’exécution aux scripts
chmod +x scripts/manage_stack.sh scripts/install_certs.sh scripts/smoke_test.sh

# 4) Démarrez en mode reconstruction complète (supprime/recrée la VM Podman si nécessaire)
./scripts/manage_stack.sh dev1 restart_from_scratch

# 5) Ouvrez l’URL locale (auto-affichée par le script à la fin)
#    Exemple: https://app.localtest.me:8443/
```

À tout moment :
```bash
./scripts/manage_stack.sh dev1 start      # démarre proprement
./scripts/manage_stack.sh dev1 stop       # arrête proprement
./scripts/manage_stack.sh dev1 restart_from_scratch  # réinitialise totalement la VM et les conteneurs
```

---

## 2) Environnements & configurations

Les **paramètres** de chaque environnement sont centralisés dans un **fichier unique** :
- `envs/dev1.env`
- `envs/recette.env`
- `envs/preprod.env`
- `envs/prod.env`

Le script principal charge **exclusivement** le fichier de l’environnement demandé et l’injecte à `podman compose`.

Les **certificats** par environnement se placent dans `certs/<env>/` :
- `certs/dev1/tls.crt`
- `certs/dev1/tls.key`
- `certs/dev1/ca.crt` (facultatif mais recommandé pour la VM Podman)

Le script `scripts/install_certs.sh` importe le **CA** dans la VM Podman (si présente) et dans le host, si nécessaire.

---

## 3) Stack de services

- **proxy** (nginx) : TLS (certs montés), reverse-proxy vers frontend et backend
- **frontend** (Vite build + Nginx statique)
- **backend** (Django + Gunicorn), dépend de **db** et **redis**
- **db** (PostgreSQL 15) + volume persistant
- **redis** (Redis 7)

> Chemins d’accès :
- Frontend : `/` (servi par Nginx frontal)
- API Backend : `/api/` (proxifiée par le frontal vers Django)
- Health backend : `/api/healthz`

---

## 4) Vérifications & tests fumée

À la fin de `start` ou `restart_from_scratch`, le script lance `scripts/smoke_test.sh` qui vérifie :
- `https://$APP_DOMAIN:$PROXY_HTTPS_PORT/`
- `https://$APP_DOMAIN:$PROXY_HTTPS_PORT/api/healthz`
- En fallback, les endpoints en HTTP si nécessaire

Les URL exactes sont récapitulées dans la sortie.

---

## 5) Développement & bonnes pratiques DevSecOps

- Activez les hooks **pre-commit** :
  ```bash
  pipx install pre-commit || pip install pre-commit
  pre-commit install
  ```
- Python : **ruff**, **black**, **bandit**
- Secrets : **detect-secrets**
- Frontend : **eslint** & **prettier** (via `frontend/`)

> CI/CD : des workflows GitHub sont fournis dans `.github/workflows/`. Ils couvrent lint/test, build d’images, et un scan de sécurité basique (Trivy gabarit).

---

## 6) Mobile (Expo) — squelette

Le dossier `mobile/` contient un projet Expo minimal (non activé par défaut). Vous pourrez l’exécuter en natif.
L’intégration conteneurisée est fournie en **profil compose** `mobile` (désactivé par défaut).

---

## 7) Commandes utiles

```bash
# Lister/inspecter la VM Podman
podman machine list
podman machine inspect <name>

# Supprimer totalement la VM (⚠️ réinitialise tout)
podman machine stop <name> && podman machine rm -f <name>
```

---

## 8) Notes RGPD & DSA (gabarits)

Voir `docs/rgpd_dsa/` pour un **registre de traitements** (modèle) et une checklist de conformité à adapter.

---

## 9) Dépannage rapide

- Port 8443/8080 occupé ? Modifiez `PROXY_HTTPS_PORT` / `PROXY_HTTP_PORT` dans `envs/<env>.env`.
- Certificats invalides ? Remplacez `certs/<env>/tls.crt` et `tls.key` par vos propres clés, puis `restart_from_scratch`.
- Windows/macOS : la gestion VM se fait via **Podman Machine** ; Linux rootless peut ne pas en créer. Le script s’adapte.
- Logs : le script affiche automatiquement les logs en cas d’erreur de démarrage.
