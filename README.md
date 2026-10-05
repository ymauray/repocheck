# repocheck

[![Lint](https://github.com/ymauray/repocheck/actions/workflows/lint.yml/badge.svg)](https://github.com/ymauray/repocheck/actions/workflows/lint.yml)
[![Release](https://img.shields.io/github/v/release/ymauray/repocheck)](https://github.com/ymauray/repocheck/releases)
[![Licence MIT](https://img.shields.io/github/license/ymauray/repocheck)](LICENSE)

Plugin Claude Code qui audite la conformité de dépôts GitHub à un référentiel de bonnes pratiques, calcule un score, propose un plan d'action, applique les actions validées et trace tout dans un journal.

## Contenu

```
.claude-plugin/          manifeste du plugin et marketplace locale
skills/repocheck/
  SKILL.md               déroulé du skill
  references/
    BONNES-PRATIQUES.md  le référentiel (36 pratiques, versionné)
    remediation.md       comment corriger chaque pratique
    journal.md           format du journal de traçabilité
  scripts/
    collect.sh           collecte des signaux via gh api (lecture seule)
    score.sh             calcul du score, poids lus dans le référentiel
  templates/             modèles de fichiers communautaires
journal/                 journaux d'audit (INDEX.md, RETOURS.md, un dossier par dépôt)
docs/archives/           référentiel d'origine, avant nettoyage
```

## Prérequis

- Claude Code
- [GitHub CLI](https://cli.github.com/) authentifié (`gh auth status`) avec des droits d'administration sur les dépôts à mettre en conformité. L'audit seul se contente d'un accès en lecture, mais certains réglages (protection de branche, sécurité) ne sont lisibles qu'avec les droits d'administration.
- Bash (Git Bash sous Windows). Aucun `jq` n'est nécessaire : le filtrage passe par `gh --jq`.

## Installation

Dans Claude Code :

```
/plugin marketplace add ymauray/repocheck
/plugin install repocheck@repocheck
```

Puis indiquer où écrire le journal, dans le bloc `env` de `~/.claude/settings.json` (sans cette variable, le skill demande l'emplacement à chaque exécution) :

```json
{
  "env": {
    "REPOCHECK_JOURNAL": "/chemin/vers/mon/journal"
  }
}
```

`/plugin marketplace update repocheck` récupère la dernière version.

### Développer le plugin

Pour travailler sur le skill ou le référentiel, déclarer plutôt la marketplace depuis un clone local : les modifications sont prises en compte après `/plugin marketplace update repocheck`, sans passer par GitHub.

```sh
git clone https://github.com/ymauray/repocheck.git
```

```
/plugin marketplace add /chemin/vers/repocheck
/plugin install repocheck@repocheck
```

## Utilisation

Il suffit de demander, en langage naturel :

| Demande | Effet |
|---|---|
| « audite ymauray/paige » | Audit et score, puis plan proposé. Rien n'est modifié. |
| « mets ymauray/paige en conformité » | Audit, plan, validation, application, ré-audit et journal. |
| « audite tous mes dépôts » | Audit en lot et tableau récapitulatif trié par score. |
| « crée un dépôt conforme ymauray/nouveau » | Création, puis mise en conformité. |
| « où en est ymauray/paige ? » | Dernier journal et historique des scores. |

Garanties :

- aucune modification sans validation explicite ;
- les fichiers passent toujours par une PR, que le skill ne merge jamais ;
- chaque réglage modifié est consigné avec son état avant, son état après et sa commande de retour arrière ;
- les actions irréversibles (suppression de tags) demandent une confirmation une par une.

Les scripts sont aussi utilisables seuls :

```sh
bash skills/repocheck/scripts/collect.sh owner/repo > collecte.txt
bash skills/repocheck/scripts/score.sh statuts.txt   # une ligne « ID OK|KO|NA » par pratique
```

## Faire évoluer le référentiel

Le référentiel est versionné (en tête de `BONNES-PRATIQUES.md`), et chaque journal indique la version utilisée.

1. Les remarques faites pendant les audits sont consignées dans `journal/RETOURS.md`.
2. Une règle modifiée ou ajoutée incrémente la version mineure ; une simple précision, la version de correctif.
3. Ajouter une pratique : une ligne dans le tableau de sa catégorie (ID, pratique, criticité en emoji, évaluation, justification) et une entrée dans `remediation.md`. `score.sh` la prend en compte automatiquement.

## Score

Les poids sont : 🔴 4 · 🟠 2 · 🟡 1 · ⚪ 0,5. Le score vaut poids OK ÷ (poids OK + poids KO) × 100 ; les `NA` sont exclus. Une dérogation acceptée reste `KO` : elle n'améliore pas le score, mais l'action n'est plus proposée.
