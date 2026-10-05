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

### Livraison du journal

Quand `$REPOCHECK_JOURNAL` est dans un dépôt Git dont la branche par défaut est protégée (c'est le cas du dépôt repocheck), le journal ne peut pas y être commité directement. À la fin de chaque exécution :

1. Depuis la racine de ce dépôt, à jour de sa branche par défaut, créer la branche `journal/<AAAA-MM-JJ-HHMM>-<repo>`.
2. N'ajouter **que les fichiers de l'exécution** : son journal, ses collectes, et les modifications d'`INDEX.md`, de `RETOURS.md` et de `DEROGATIONS.md`. Un seul commit : `journal: <owner/repo> (<mode>, <AAAA-MM-JJ HH:MM>)`.
3. Pousser, ouvrir la PR « Journal : <owner/repo> (<AAAA-MM-JJ>) », puis revenir sur la branche par défaut.
4. Ne pas merger la PR : c'est à l'utilisateur de le faire. Donner son URL dans le résumé final.

Si le dossier n'est pas versionné, ou si sa branche par défaut n'est pas protégée, cette étape ne s'applique pas.

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

## Badge

- Actuel : `repocheck 1.2.0 | 58/100`, périmé (référentiel courant 1.3.0, score de l'audit 62)

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
- Score attendu une fois les actions validées appliquées : 81/100 → badge `repocheck 1.3.0 | 81/100`, `green`

## Actions exécutées

### 10:51 — SEC-01 — API — ✅
- Commande : `gh api -X PUT repos/owner/repo/vulnerability-alerts`
- Avant : désactivées (404)
- Après : activées
- Retour arrière : `gh api -X DELETE repos/owner/repo/vulnerability-alerts`

### 10:58 — PR #12 — ✅
- URL : https://github.com/owner/repo/pull/12
- Branche : repocheck/2026-10-05
- Commits : META-07 (abc1234), GOV-05 (def5678), badge 81/100 (0a1b2c3)
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
