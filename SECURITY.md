# Politique de sécurité

## Signaler une vulnérabilité

Merci de ne pas ouvrir d'issue publique pour signaler une vulnérabilité de sécurité.

Utilisez plutôt l'onglet **Security** du dépôt puis **Report a vulnerability** (private vulnerability reporting), afin que le signalement reste confidentiel jusqu'à correction.

## Périmètre

RepoCheck est un outil local qui lit et écrit des fichiers Markdown/CSV, et interroge l'API GitHub via `gh` (authentification déléguée à `gh`, aucun secret n'est stocké par l'outil lui-même).
