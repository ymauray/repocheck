# RepoCheck

[![Lint](https://github.com/ymauray/repocheck/actions/workflows/lint.yml/badge.svg)](https://github.com/ymauray/repocheck/actions/workflows/lint.yml)
[![Licence : MIT](https://img.shields.io/badge/Licence-MIT-blue.svg)](LICENSE)

RepoCheck audite des dépôts GitHub par rapport à un référentiel de bonnes pratiques, et produit des rapports de conformité en Markdown.

## Principe

Trois éléments distincts :

- **`github-bonnes-pratiques.md`** — le catalogue des pratiques évaluées (ID stable, catégorie, criticité, description), indépendant de tout dépôt.
- **`github-audits.csv`** — la matrice de résultats : une ligne par dépôt, une colonne par ID de pratique (`OK` / `KO` / `NA`), plus une colonne `Notes` pour les cas particuliers. Ce fichier est généré/mis à jour localement et n'est pas versionné.
- **`Invoke-RepoCheck.ps1`** — le script qui fusionne les deux pour produire les rapports.

## Prérequis

- PowerShell 5.1+ ou [PowerShell 7+](https://github.com/PowerShell/PowerShell)
- [GitHub CLI](https://cli.github.com/) (`gh`), authentifié, pour l'audit d'un dépôt via l'API GitHub

## Utilisation

Générer un rapport Markdown par dépôt (dans `reports/`) :

```powershell
./Invoke-RepoCheck.ps1 -Reports
```

Générer le rapport global (tous les dépôts, triés par score croissant) :

```powershell
./Invoke-RepoCheck.ps1 -Summary
```

Combiner les deux, ou limiter à un dépôt :

```powershell
./Invoke-RepoCheck.ps1 -Reports -Summary
./Invoke-RepoCheck.ps1 -Reports -Repo owner/repo
```

### Score de conformité

Chaque pratique a un poids selon sa criticité (🔴 Haute = 4, 🟠 Moyenne = 3, 🟡 Faible = 2, ⚪ Optionnel = 1). Le score d'un dépôt est la somme des poids des pratiques respectées, divisée par la somme des poids des pratiques applicables (les `NA` sont exclus du calcul).

## Paramètres

| Paramètre | Description | Défaut |
|---|---|---|
| `-Reports` | Génère un rapport Markdown par dépôt | — |
| `-Summary` | Génère le rapport global | — |
| `-Repo` | Limite le traitement à un ou plusieurs dépôts | tous les dépôts du CSV |
| `-CatalogPath` | Chemin du catalogue | `github-bonnes-pratiques.md` |
| `-CsvPath` | Chemin de la matrice de résultats | `github-audits.csv` |
| `-OutputDir` | Dossier des rapports par dépôt | `reports/` |
| `-SummaryPath` | Chemin du rapport global | `github-audits-summary.md` |

## Intégration continue et releases

Un seul workflow GitHub Actions, [`lint.yml`](.github/workflows/lint.yml), déclenché à chaque push sur `main` et à chaque pull request vers `main`. Il enchaîne deux étapes :

- **PSScriptAnalyzer** sur tout le dépôt (`-Severity Warning,Error`) : le job échoue sur une erreur, les avertissements sont seulement affichés.
- **Smoke test** : `./Invoke-RepoCheck.ps1 -Reports -Summary` est lancé sur la fixture [`tests/fixtures/sample-audits.csv`](tests/fixtures/sample-audits.csv), avec des sorties écrites hors du dépôt. Le catalogue réel est parsé à chaque exécution — une ligne de tableau mal formée dans `github-bonnes-pratiques.md` fait donc échouer la CI.

La branche `main` est protégée : force-push et suppression interdits, check `Lint` obligatoire et branche à jour avant merge, protection appliquée **aussi aux administrateurs**. Toute modification passe par une pull request, y compris celles du mainteneur.

Dependabot surveille les versions des actions GitHub ([`dependabot.yml`](.github/dependabot.yml), hebdomadaire). C'est le seul écosystème déclaré : RepoCheck n'a aucune dépendance applicative en dehors de PowerShell et `gh`.

**Il n'y a ni release, ni package, ni artefact publié**, et aucun outil de CI/CD externe au dépôt n'intervient : RepoCheck se livre en clonant le dépôt et en lançant le script. Aucun tag versionné n'est donc maintenu — c'est un choix, pas un oubli.

## Statut

`github-audits.csv` est aujourd'hui rempli manuellement à partir d'un audit via `gh api`. Une prochaine étape consiste à automatiser cet audit (mode `-Audit`) puis à appliquer des corrections sûres (mode `-Fix`).

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.
