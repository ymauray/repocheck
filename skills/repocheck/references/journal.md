# Journal de traçabilité

Le journal permet de savoir, pour chaque dépôt et à tout moment : ce qui a été constaté, ce qui a été proposé, ce qui a été validé ou refusé (et pourquoi), ce qui a été fait, et comment revenir en arrière.

## Emplacement

Le dossier est donné par la variable d'environnement `REPOCHECK_JOURNAL`. Si elle n'est pas définie, demander à l'utilisateur où écrire, en proposant le dossier `journal/` du dépôt repocheck, puis lui suggérer de définir la variable (dans le bloc `env` de `~/.claude/settings.json`).

```
$REPOCHECK_JOURNAL/
├── INDEX.md                         # une ligne par exécution, tous dépôts confondus
├── RETOURS.md                       # retours de l'utilisateur sur le référentiel et le skill
└── <owner>/<repo>/
    ├── DEROGATIONS.md               # écarts acceptés durablement pour ce dépôt
    ├── <AAAA-MM-JJ-HHMM>.md          # journal d'une exécution
    └── <AAAA-MM-JJ-HHMM>.collecte.txt  # sortie brute de collect.sh (preuve)
```

Règles :

- **Ne jamais modifier une entrée passée** : un journal d'exécution n'est complété que pendant sa propre exécution. Une erreur se corrige par une nouvelle entrée.
- Écrire au fil de l'eau, et non en fin d'exécution, pour qu'une interruption ne fasse pas perdre la trace de ce qui a déjà été fait.
- Horodatages en heure locale, au format ISO 8601 avec fuseau (`2026-10-05T10:42:00+02:00`).
- Ne jamais consigner de secret (token, clé) : les masquer s'il en apparaît dans une sortie.

## Journal d'exécution — modèle

```markdown
# repocheck — owner/repo — 2026-10-05 10:42

- Référentiel : version 1.0.0
- Mode : audit | mise en conformité | création
- Collecte brute : [2026-10-05-1042.collecte.txt](2026-10-05-1042.collecte.txt)
- Qualification : dépôt de code, mainteneur unique, public

## Audit initial — score 62/100

| ID | Criticité | Statut | Constat |
|---|---|---|---|
| META-03 | 🔴 | KO | Aucune licence détectée. |
| BR-04 | ⚪ | NA | Mainteneur unique. |
| GOV-07 | ⚪ | KO (dérogation) | Voir DEROGATIONS.md. |
...

## Avertissements

- CI-06 : tags hors versions sur `main` : `jalon-1` … `jalon-11` (n'entrent pas dans le score).

## Plan proposé

| # | ID | Type | Action | Impact / risque |
|---|---|---|---|---|
| 1 | SEC-01 | API | Activer les Dependabot alerts | Aucun |
| 2 | BR-05 | API | enforce_admins | Push direct sur main refusé sans checks verts |
...

## Décisions de l'utilisateur

- Validées : 1, 2, 4
- Refusées : 3 (GOV-07) — « je ne veux pas de Discussions sur ce projet » → enregistrée en dérogation
- Reportées : 5

## Actions exécutées

### 10:51 — SEC-01 — API — ✅
- Commande : `gh api -X PUT repos/owner/repo/vulnerability-alerts`
- Avant : désactivées (404)
- Après : activées
- Retour arrière : `gh api -X DELETE repos/owner/repo/vulnerability-alerts`

### 10:58 — PR #12 — ✅
- URL : https://github.com/owner/repo/pull/12
- Branche : repocheck/2026-10-05
- Commits : META-07 (abc1234), GOV-05 (def5678)
- Retour arrière : fermer la PR sans merger

### 11:02 — BR-05 — API — ❌
- Erreur : HTTP 422 ...
- Suite donnée : ...

## Audit final — score 81/100 (+19)

Pratiques passées à OK : SEC-01, BR-05...
En attente du merge de la PR #12 : META-07, GOV-05 (ces pratiques passeront à OK au merge)

## Retours

- (remarques de l'utilisateur sur des règles ou des propositions, reportées aussi dans RETOURS.md)
```

## INDEX.md

Ajouter une ligne en fin d'exécution (créer le fichier avec l'en-tête s'il n'existe pas) :

```markdown
| Date | Dépôt | Mode | Score avant | Score après | PR | Journal |
|---|---|---|---|---|---|---|
| 2026-10-05 10:42 | owner/repo | mise en conformité | 62 | 81 | #12 | [lien](owner/repo/2026-10-05-1042.md) |
```

## DEROGATIONS.md

Un écart que l'utilisateur refuse de corriger **durablement** est enregistré ici, uniquement avec son accord explicite. Un simple refus ponctuel (« pas maintenant ») n'est pas une dérogation.

```markdown
| ID | Depuis | Motif | Revoir le |
|---|---|---|---|
| GOV-07 | 2026-10-05 | Pas de Discussions : projet personnel, les issues suffisent. | — |
```

Effet : la pratique reste `KO` dans le score, mais elle est signalée « (dérogation) » et n'est plus proposée dans le plan, sauf si sa date de révision est passée.

## RETOURS.md

Toute remarque de l'utilisateur qui remet en cause une règle du référentiel ou un comportement du skill :

```markdown
## 2026-10-05 — owner/repo
- **Constat** : CI-06 compte KO des tags `jalon-N` qui sont des jalons de développement, pas des versions.
- **Proposition** : ...
- **Décision** : en attente | appliquée au référentiel v1.1.0 | rejetée
```
