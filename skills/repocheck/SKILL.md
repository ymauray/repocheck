---
name: repocheck
description: Audite la conformité d'un dépôt GitHub au référentiel de bonnes pratiques (métadonnées, gouvernance, CI/CD, protection de branche, sécurité, outillage IA), calcule un score, propose un plan d'action, applique les actions validées par l'utilisateur et trace tout dans un journal. À utiliser quand l'utilisateur veut auditer, vérifier, noter ou mettre en conformité un ou plusieurs dépôts GitHub, créer un nouveau dépôt conforme, ou consulter l'historique des audits.
---

# repocheck

Ce skill fonctionne en quatre temps : audit, plan, application, puis trace. Il **ne modifie jamais rien** sans validation explicite de l'utilisateur, et tout ce qu'il constate, propose et fait est consigné dans le journal.

Fichiers du skill (chemins relatifs à ce dossier) :

- `references/BONNES-PRATIQUES.md` : le référentiel. **Le lire en entier avant toute évaluation.** C'est la seule source des règles : ne pas en inventer.
- `references/remediation.md` : comment corriger chaque pratique. À lire avant de proposer le plan.
- `references/journal.md` : le format et l'emplacement du journal. À lire avant d'écrire la première entrée.
- `scripts/collect.sh` : la collecte des signaux, en lecture seule.
- `scripts/score.sh` : le calcul du score à partir des statuts.
- `templates/` : les modèles de fichiers communautaires.

Langue : le français, pour les échanges comme pour le journal.

## Modes

| Demande | Mode |
|---|---|
| « audite / note / vérifie owner/repo » | **audit** : étapes 1 à 4, puis proposer de passer à la mise en conformité |
| « mets en conformité owner/repo » | **mise en conformité** : étapes 1 à 7 |
| « audite tous mes dépôts » | **audit en lot** : étapes 1 à 3 pour chaque dépôt, puis un tableau récapitulatif trié par score croissant. Un journal par dépôt, sans plan. |
| « crée un dépôt conforme » | **création** : voir la section dédiée |
| « historique / où en est owner/repo » | lire `INDEX.md` et le dernier journal du dépôt |

Sans `owner/repo` explicite, utiliser le dépôt du répertoire courant (`gh repo view`). Pour un lot, utiliser `gh repo list <owner> --no-archived --source --limit 200`.

## 1. Collecter

```bash
bash <dossier du skill>/scripts/collect.sh owner/repo > <journal>/<owner>/<repo>/<AAAA-MM-JJ-HHMM>.collecte.txt
```

Le script ne fait que lire. Les sections sont délimitées par `===== [repocheck] ... =====`. Vérifier `gh auth status` au préalable si un appel échoue en `401`.

Si un signal manque dans la collecte (contenu d'un fichier précis, sous-dossier, run de workflow), aller le chercher avec `gh api`, toujours en lecture seule, et le mentionner dans le constat.

## 2. Qualifier puis évaluer

1. **Qualifier le dépôt** selon la typologie du référentiel : sans code, de distribution, déclaratif, mainteneur unique (un seul collaborateur avec droit d'écriture), public ou privé, archivé.
2. Lire `DEROGATIONS.md` du dépôt s'il existe.
3. Évaluer **chacune** des pratiques du référentiel : statut `OK`, `KO` ou `NA`, avec les éventuels avertissements que prévoit le référentiel, plus un constat factuel d'une ligne qui cite le signal observé (« enforce_admins.enabled = false », « aucun fichier .editorconfig »). Un `NA` doit s'appuyer sur une condition écrite dans le référentiel.
4. Si un signal est ambigu (contenu du README, outil de release externe possible, choix de l'assistant IA), poser la question à l'utilisateur plutôt que de trancher au hasard.
5. Calculer le score avec `scripts/score.sh`, jamais à la main. Le script prend une ligne `ID STATUT` par pratique, lit les poids dans le référentiel et refuse une liste incomplète ou contenant des doublons. Une dérogation s'y écrit `KO`.
6. Relever le **badge repocheck** du README (voir « Badge repocheck » dans `references/remediation.md`) : absent, à jour, ou périmé (version du référentiel ou score différents du résultat de l'audit). Le badge est une fonctionnalité du skill, pas une pratique : il n'entre pas dans le score.

## 3. Rapporter

Créer le journal d'exécution (modèle dans `references/journal.md`), puis afficher à l'utilisateur :

- le score et sa répartition (nombre de OK, KO et NA) ;
- **les KO seulement**, triés par criticité : ID, pratique, constat ;
- la liste des NA, sur une ligne, avec leur justification abrégée ;
- les **avertissements** prévus par le référentiel, qui n'entrent pas dans le score ;
- les éventuelles causes structurelles, par exemple un dépôt privé en plan gratuit (voir le référentiel) ;
- l'état du badge repocheck : absent, à jour, ou périmé (ce qu'il affiche et ce qu'il devrait afficher).

## 4. Proposer un plan

Pour chaque KO hors dérogation, proposer une action d'après `references/remediation.md`, avec :

- son **type** : API (immédiat) ou PR (fichier) ;
- son **impact** sur les habitudes ou workflows existants, en particulier enforce_admins + checks requis (le push direct devient impossible), CI-07 (casse un workflow qui écrit sans `permissions:`) et CI-02 (des noms de checks inexacts bloquent tous les merges) ;
- les **informations à fournir** par l'utilisateur, le cas échéant : licence, contact du code de conduite, outils externes, assistant IA ;
- les actions irréversibles, signalées comme telles.

Ordre conseillé : sécurité (SEC) et réglages API sans impact d'abord, puis les fichiers en une seule PR, et la protection de branche **en dernier**, une fois la CI vérifiée.

Ajouter au plan une action **badge** (type PR) si le badge est absent ou ne correspondra pas au score attendu. Ce score est celui que donnera `score.sh` une fois les actions validées appliquées, puisque le badge part dans la PR, avant le merge et avant les actions qui le suivent (protection de branche). L'action est facultative : un refus est consigné dans le journal, sans dérogation.

Écrire le plan dans le journal, puis demander la validation (AskUserQuestion) : tout appliquer, choisir des actions, ou ne rien faire. Pour chaque action refusée, demander s'il s'agit d'un report ou d'une **dérogation durable** et en noter le motif.

Une fois les décisions prises, calculer le **score attendu** avec `scripts/score.sh` : chaque KO visé par une action validée y est passé à `OK`, et les pratiques qu'une action rend applicables (CI-03 et CI-04 à la création d'un workflow, par exemple) y sont évaluées. Le consigner dans le journal : c'est lui qu'affiche le badge.

## 5. Appliquer (actions validées uniquement)

- **API** : relever l'état « avant », exécuter, relever l'état « après », puis consigner les trois avec la commande de retour arrière, **action par action et immédiatement**.
- **PR** : suivre « Mise en œuvre d'une PR » dans `references/remediation.md` : clone dans le scratchpad, un commit par pratique, PR non mergée. Le badge fait l'objet du **dernier** commit, avec le score attendu.
- En cas d'échec : consigner l'erreur, ne pas improviser de contournement, continuer avec les actions indépendantes et signaler l'échec dans le résumé.

## 6. Vérifier

Relancer la collecte et l'évaluation, puis consigner l'audit final : nouveau score, pratiques passées à OK, et pratiques en attente du merge de la PR. Ajouter la ligne d'`INDEX.md`.

Si une action validée a échoué ou a été abandonnée, le score attendu ne sera pas atteint : le signaler dans le journal et dans le résumé, car le badge de la PR sera alors faux. La prochaine exécution le détectera comme périmé et proposera de le corriger.

## 7. Recueillir les retours

Demander brièvement à l'utilisateur si une évaluation ou une proposition lui a paru fausse. Toute remarque qui touche une règle :

1. est consignée dans le journal et dans `RETOURS.md` ;
2. donne lieu, si l'utilisateur le souhaite, à une proposition de modification du référentiel **dans le dépôt source du plugin** (pas dans la copie installée), en incrémentant sa version : correctif → `x.y.Z`, nouvelle règle ou règle modifiée → `x.Y.0`.

## 8. Livrer le journal

Si le dossier du journal se trouve dans un dépôt Git dont la branche par défaut est protégée, livrer les fichiers de l'exécution par une PR, en suivant « Livraison du journal » dans `references/journal.md`. Cette étape vaut pour tous les modes, audit seul compris.

## Création d'un dépôt

1. Demander le nom, la description, la visibilité, la licence et le langage.
2. `gh repo create owner/nom --<visibilité> --description "..." --license <spdx> --gitignore <Lang> --clone=false`
3. Enchaîner un audit et un plan sur ce dépôt neuf. Le premier lot de fichiers peut être poussé directement sur la branche par défaut, puisqu'aucune protection n'existe encore : le proposer, puis appliquer la protection de branche en dernier.

## Ce que le skill ne fait jamais

- Merger une PR, pousser directement sur la branche par défaut d'un dépôt existant, ou forcer un push.
- Supprimer un tag, une branche, un fichier ou une release sans confirmation individuelle.
- Changer la visibilité d'un dépôt, ou toucher aux secrets et aux réglages de facturation.
- Modifier un journal d'exécution passé.
