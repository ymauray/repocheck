# Contribuer à {{PROJET}}

Merci de vous intéresser à {{PROJET}} ! Ce document résume comment proposer une contribution.

## Avant de commencer

Pour une nouvelle fonctionnalité ou un changement important, ouvrez d'abord une issue <!-- repocheck: « ou une discussion » si les Discussions sont activées --> pour en parler avec le mainteneur.

## Environnement de développement

<!-- repocheck: prérequis réels (langage, version, outils) -->

```sh
{{BUILD}}
{{TEST}}
```

## Proposer une modification

1. Créez une branche dédiée depuis `{{BRANCHE}}` (ex. `fix/...`, `feature/...`).
2. Faites des commits atomiques, avec des messages clairs.
3. Vérifiez que les tests passent en local.
4. Ouvrez une pull request vers `{{BRANCHE}}` en remplissant le modèle fourni. Les PR sont mergées en squash.

<!-- repocheck: conventions propres au projet (langue du code, en-têtes de licence, architecture), reprises de CLAUDE.md ou AGENTS.md s'ils existent -->
