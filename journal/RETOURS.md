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
