# Modèles

Points de départ pour les fichiers communautaires, à **adapter** au dépôt cible (voir `references/remediation.md`).

Variables à remplacer : `{{PROJET}}` (nom affiché), `{{REPO}}` (`owner/repo`), `{{BRANCHE}}` (branche par défaut), `{{BUILD}}` et `{{TEST}}` (commandes réelles).

Les blocs entre `<!-- repocheck: ... -->` sont des consignes de rédaction : il faut les remplacer par du contenu ou les supprimer.

| Modèle | Pratique | Emplacement cible |
|---|---|---|
| `.editorconfig` | META-07 | racine |
| `CONTRIBUTING.md` | GOV-01 | racine |
| `SECURITY.md` | GOV-03 | racine |
| `.github/ISSUE_TEMPLATE/*` | GOV-04 | `.github/ISSUE_TEMPLATE/` |
| `.github/pull_request_template.md` | GOV-05 | `.github/` |
| `.github/SUPPORT.md` | GOV-08 | `.github/` |
| `CLAUDE.md` | TOOL-01 | racine (à utiliser tel quel) |
