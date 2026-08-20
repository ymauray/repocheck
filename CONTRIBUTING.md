# Contribuer à RepoCheck

## Proposer une modification

1. Créez une branche dédiée à partir de `main`.
2. Faites vos modifications (script, catalogue de pratiques, documentation).
3. Ouvrez une pull request vers `main`. Le workflow de lint doit passer avant merge.

## Modifier le catalogue de pratiques

`github-bonnes-pratiques.md` a un format attendu (parsé par le script) :

- Chaque catégorie est un titre `## Nom de la catégorie`.
- Chaque pratique est une ligne de tableau `| ID | Pratique | Criticité | Commentaire |`.
- L'ID suit le format `PREFIXE-NN` (ex: `SEC-04`) et doit rester stable une fois publié : il correspond au nom de colonne dans `github-audits.csv`.
- La criticité est l'un des emojis 🔴 (Haute), 🟠 (Moyenne), 🟡 (Faible), ⚪ (Optionnel).

## Modifier le script

`Invoke-RepoCheck.ps1` vise la compatibilité PowerShell 5.1+ et 7+ : éviter les opérateurs propres à PowerShell 7 (`??`, `?:`).

## Signaler un bug ou proposer une fonctionnalité

Ouvrez une issue en utilisant le template correspondant.
