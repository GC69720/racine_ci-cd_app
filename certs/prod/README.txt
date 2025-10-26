Placez ici vos certificats pour l'environnement 'prod'.

- tls.crt  : certificat serveur (PEM)
- tls.key  : clé privée (PEM)
- ca.crt   : autorité racine/chaîne (optionnel mais recommandé pour la VM Podman)

Des certificats auto-signés d'exemple seront (facultatif) générés par vous en local,
puis ajoutés via scripts/install_certs.sh si nécessaire.
