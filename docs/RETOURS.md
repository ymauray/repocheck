# Retours sur le référentiel et le skill

## 2026-10-05 — validation initiale (prizm, paige, timetracker.ios)

### GOV-03 : un SECURITY.md dont le canal ne fonctionne pas
- **Constat** : `paige/SECURITY.md` renvoie vers le signalement privé de vulnérabilités, qui est désactivé. À la lettre du référentiel, le fichier existe, donc `OK` ; dans les faits, le signalement est impossible.
- **Proposition** : préciser GOV-03 : « `KO` si le canal indiqué n'est pas opérationnel (signalement privé désactivé, adresse absente) ».
- **Décision** : validée par l'utilisateur le 2026-10-05, appliquée au référentiel v1.0.1

### CI-06 : tags de jalon
- **Constat** : prizm utilise des tags `jalon-N` pour marquer les étapes de développement, avant toute release. CI-06 les compte en `KO`.
- **Proposition** : soit garder la règle (et poser une dérogation sur prizm), soit tolérer un préfixe de jalon documenté.
- **Décision** (2026-10-05, utilisateur) : pour le moment, les tags autres que les tags de version présents sur `main` sont consignés en **avertissement**, sans effet sur le score. CI-06 ne juge plus que le format des tags de version. Appliquée au référentiel v1.2.0, qui introduit la notion d'avertissement. À réexaminer.

### TOOL-01 : fichier au bon nom, contenu destiné à un autre outil
- **Constat** : `paige/GEMINI.md` est rédigé pour Claude Code, qui ne lit que `CLAUDE.md`.
- **Proposition** : préciser TOOL-01 : « le contenu doit correspondre à l'outil qui lit ce fichier ».
- **Décision** : remplacée le 2026-10-05 par une règle plus simple, voulue par l'utilisateur : `AGENTS.md` obligatoire, et `CLAUDE.md` qui l'importe (`@AGENTS.md`). Les autres fichiers sont tolérés, sans être évalués. Appliquée au référentiel v1.1.0.
- **Effet sur les audits existants** : timetracker.ios passe en KO (son `CLAUDE.md` contient un lien, pas l'import) ; paige reste KO (`AGENTS.md` et `CLAUDE.md` absents) ; prizm reste OK.

### Précisions ajoutées au nettoyage (v1.0.0), à valider
- `NA` en l'absence de workflow pour CI-03 et CI-04 ; `NA` en l'absence de tag pour CI-06.
- Un ruleset équivaut à la protection de branche classique.
- SEC-03 doit couvrir `github-actions` dès qu'il y a des workflows (repris de l'avertissement de CI-04).
- Poids du score : 4 / 2 / 1 / 0,5 ; une dérogation reste `KO` dans le score.
- **Décision** : validées par l'utilisateur le 2026-10-05.

## 2026-10-05 — mise sous Git du plugin

### META-10 : `.gitattributes`
- **Constat** : en publiant repocheck, le `core.autocrlf` de Git for Windows aurait extrait `collect.sh` et `score.sh` en CRLF, ce qui les rend inutilisables sous bash. Aucun des dépôts audités (prizm, paige, timetracker.ios) n'a de `.gitattributes`.
- **Proposition** : nouvelle pratique META-10 🟡 : `.gitattributes` qui normalise les fins de ligne.
- **Décision** : validée par l'utilisateur le 2026-10-05, ajoutée au référentiel v1.3.0 (36 pratiques).

## 2026-10-05 — mise en conformité de repocheck

### Journal et protection de branche
- **Constat** : le journal est versionné dans repocheck. Une fois `main` protégée (`enforce_admins` et check `Lint` requis), il ne peut plus y être commité directement.
- **Options** : une PR par exécution, un journal hors du dépôt, ou une dérogation sur la protection.
- **Décision** (utilisateur) : une PR par exécution. Ajout de l'étape 8 « Livrer le journal » dans `SKILL.md` et de la section « Livraison du journal » dans `references/journal.md` ; plugin en 0.5.0.

### Collecte : les modèles comptés comme fichiers communautaires
- **Constat** : `collect.sh` liste `skills/repocheck/templates/SECURITY.md`, etc. parmi les fichiers communautaires. L'évaluation s'en tient aux emplacements canoniques, mais le bruit peut induire en erreur.
- **Proposition** : limiter la recherche des fichiers communautaires à la racine, `.github/` et `docs/`.
- **Décision** : en attente

## 2026-10-05 — audit interrompu de ymauray/encrine

### Dépôts privés : ne rien faire
- **Constat** : l'audit de `ymauray/encrine`, dépôt privé, a écrit sa collecte (README, workflows, tags) dans `journal/`, versionné dans le dépôt public repocheck et livré par PR. Interrompu à temps, la collecte supprimée avant tout commit.
- **Proposition** : le skill ne traite aucun dépôt privé.
- **Décision** (2026-10-05, utilisateur) : appliquée au plugin 0.7.0. Étape 0 du skill : vérifier la visibilité et s'arrêter sans rien écrire si le dépôt n'est pas public ; `collect.sh` refuse un dépôt non public ; l'audit en lot ne liste que les dépôts publics ; la création ne crée que des dépôts publics. La section « Dépôts privés » du référentiel devient sans objet : à retirer lors de sa prochaine révision.

## 2026-10-05 — badge de ymauray/repocheck

### Badge : un exemple pris pour le badge
- **Constat** : l'audit de repocheck (2026-10-05 17:01) a déclaré le badge « à jour » en s'appuyant sur l'exemple de la section « Badge » du README. Le README n'avait aucun badge repocheck en tête.
- **Proposition** : ne repérer le badge que dans le bloc de tête du README, avant le premier titre `##`.
- **Décision** (2026-10-05, utilisateur) : appliquée à `remediation.md` (plugin 0.7.0), et badge `repocheck 1.3.0 | 100/100` ajouté en tête du README de repocheck.

## 2026-10-05 — journal local

### Le journal quitte le dépôt repocheck
- **Constat** : versionner le journal dans repocheck impose une PR par exécution et de lancer le skill depuis ce dossier.
- **Décision** (2026-10-05, utilisateur) : le journal reste en local, dans le dossier donné par `REPOCHECK_JOURNAL` (demandé à l'utilisateur s'il n'est pas défini). Suppression de l'étape 8 « Livrer le journal ». `RETOURS.md` passe dans `docs/` ; le skill ne l'alimente plus et ne propose plus de lui-même de modifier le référentiel : l'utilisateur le demande explicitement. Plugin 0.8.0.

## 2026-10-08 — AUDIT.md

### Résultat de l'audit dans le dépôt audité
- **Constat** : le résultat d'un audit n'est lisible que dans le journal local, hors du dépôt.
- **Décision** (2026-10-08, utilisateur) : à chaque mise en conformité (pas pour un audit seul, qui ne modifie rien), le skill propose un `AUDIT.md` à la racine du dépôt audité (date, version du référentiel, score, tableau code / description / criticité / résultat), sans historique. Il part par une PR non mergée, avec le score attendu comme le badge, NA compris. Ce n'est pas une pratique : le référentiel et le score ne changent pas. Plugin 0.9.0.

### AUDIT.md généré par un script, avec légende des criticités
- **Constat** : `AUDIT.md` n'avait pas de modèle, donc sa structure dépendait de la rédaction du modèle. Le tableau affiche des pastilles (🔴 🟠 🟡 ⚪) sans dire ce qu'elles signifient ni ce qu'elles pèsent dans le score.
- **Décision** (2026-10-08, utilisateur) : le fichier est produit par `scripts/audit-md.sh`, qui lit le référentiel et réutilise `score.sh`. Il ajoute une légende (criticité, niveau, poids) reprise de la ligne « Criticité et poids dans le score » du référentiel, plus une phrase sur le calcul. Le référentiel et le score ne changent pas. Plugin 0.10.0.
