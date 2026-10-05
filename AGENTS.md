# AGENTS.md — consignes pour les agents de code

repocheck est un plugin Claude Code. Son skill audite des dépôts GitHub par rapport à un référentiel de bonnes pratiques, propose un plan d'action, applique ce que l'utilisateur valide et trace tout dans un journal.

## Structure

- `skills/repocheck/SKILL.md` : le déroulé du skill (modes, étapes, interdits).
- `skills/repocheck/references/BONNES-PRATIQUES.md` : le référentiel, **seule source des règles**. Versionné en tête de fichier.
- `skills/repocheck/references/remediation.md` : comment corriger chaque pratique.
- `skills/repocheck/references/journal.md` : format du journal.
- `skills/repocheck/scripts/collect.sh` : collecte via `gh api`, **lecture seule**.
- `skills/repocheck/scripts/score.sh` : score calculé à partir des poids lus dans le référentiel.
- `skills/repocheck/templates/` : modèles de fichiers communautaires.
- `journal/` : historique des exécutions (`INDEX.md`, `RETOURS.md`, un dossier par dépôt).

## Règles

- Tout en français : documentation, référentiel, journal, messages de commit.
- Fins de ligne LF (`.gitattributes`) : un script bash en CRLF ne s'exécute pas.
- Scripts : bash portable (Git Bash sous Windows compris), sans `jq` externe : filtrer avec `gh --jq`. Ils doivent passer `bash -n` et `shellcheck`.
- `collect.sh` ne modifie jamais rien. Toute écriture sur un dépôt audité passe par le skill, après validation de l'utilisateur.
- Référentiel : toute modification incrémente sa version (`x.y.Z` précision, `x.Y.0` règle ajoutée ou modifiée), s'accompagne de l'entrée correspondante dans `remediation.md` et d'une décision dans `journal/RETOURS.md`. Le tableau garde le format `| ID | Pratique | Criticité | Évaluation | Pourquoi |`, lu par `score.sh`.
- Plugin : incrémenter `version` dans `.claude-plugin/plugin.json` à chaque changement publié ; le workflow `Release` publie la version au merge.
- Journal : ne jamais modifier une entrée d'exécution passée.

## Vérifier

```sh
for f in skills/repocheck/scripts/*.sh; do bash -n "$f"; done
shellcheck skills/repocheck/scripts/*.sh
grep -oE '^\| [A-Z]+-[0-9]+ \|' skills/repocheck/references/BONNES-PRATIQUES.md | tr -d '| ' \
  | sed 's/$/ OK/' | bash skills/repocheck/scripts/score.sh   # 100/100 attendu
claude plugin validate .
```
