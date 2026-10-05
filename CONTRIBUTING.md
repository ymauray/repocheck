# Contribuer à repocheck

Merci de vous intéresser à repocheck ! Ce document résume comment proposer une contribution.

## Avant de commencer

Pour une nouvelle pratique, une règle modifiée ou un changement du déroulé du skill, ouvrez d'abord une [discussion](https://github.com/ymauray/repocheck/discussions) ou une issue pour en parler avec le mainteneur.

## Conventions

- **Langue** : documentation, référentiel, journal et messages de commit en français.
- **Fins de ligne** : LF partout (imposé par `.gitattributes`). Un script bash avec des fins de ligne CRLF ne s'exécute pas.
- **Référentiel** (`skills/repocheck/references/BONNES-PRATIQUES.md`) :
  - toute modification incrémente sa version : `x.y.Z` pour une précision, `x.Y.0` pour une règle ajoutée ou modifiée ;
  - toute pratique ajoutée a son entrée dans `remediation.md` ;
  - la décision est consignée dans `docs/RETOURS.md`.
- **Plugin** : incrémenter `version` dans `.claude-plugin/plugin.json`. Chaque nouvelle version est publiée automatiquement au merge (voir le README).
- **Journal** : une entrée d'exécution passée ne se modifie jamais.

## Vérifier en local

```sh
for f in skills/repocheck/scripts/*.sh; do bash -n "$f"; done
shellcheck skills/repocheck/scripts/*.sh
grep -oE '^\| [A-Z]+-[0-9]+ \|' skills/repocheck/references/BONNES-PRATIQUES.md | tr -d '| ' \
  | sed 's/$/ OK/' | bash skills/repocheck/scripts/score.sh   # doit afficher 100/100
claude plugin validate .
```

## Proposer une modification

1. Créez une branche dédiée depuis `main`.
2. Faites des commits atomiques, avec des messages clairs.
3. Vérifiez que les contrôles ci-dessus passent.
4. Ouvrez une pull request vers `main` en remplissant le modèle fourni. Les PR sont mergées en squash.
