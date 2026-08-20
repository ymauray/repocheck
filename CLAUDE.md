# Contexte projet — RepoCheck

Ce fichier est destiné à toute instance de Claude Code qui reprendrait ce travail (nouvelle session, machine différente, mémoire de conversation non partagée). Pour l'usage de l'outil lui-même, voir `README.md`. Pour les règles de contribution au code, voir `CONTRIBUTING.md`.

## Où on en est

On construit encore le **référentiel** de bonnes pratiques (`github-bonnes-pratiques.md`) en auditant des dépôts GitHub réels un par un, à la main. Le mode `-Audit` (automatisation de la collecte via `gh api`) n'est **volontairement pas encore implémenté** : le lancer trop tôt figerait le catalogue avant qu'il ait été confronté à assez de types de dépôts différents (langages, mono vs multi-projet, solo vs équipe...).

La liste des dépôts déjà audités, leurs scores et les notes détaillées vivent dans `github-audits.csv` (local uniquement, voir plus bas pourquoi). Consulte ce fichier s'il est présent dans le dossier de travail — c'est la seule source de vérité sur l'état d'avancement. `ymauray/repocheck` (ce dépôt) y figure aussi : il s'auto-audite pour dogfooding.

## Méthodologie pour auditer un nouveau dépôt

1. Collecter les données via `gh repo view`, `gh api repos/{owner}/{repo}/...` (contents, branches/{branch}/protection, security_and_analysis, vulnerability-alerts, contents/.github/workflows/*, contributors...).
2. Comparer chaque pratique du catalogue au dépôt réel : `OK`, `KO`, ou `NA` si la pratique ne s'applique pas dans ce contexte (ex: revues obligatoires pour un mainteneur solo).
3. Si un écart intéressant ou une pratique manquante dans le catalogue apparaît (ex: `enforce_admins`, généralisation du fichier d'instructions IA...), en discuter avec l'utilisateur avant de modifier `github-bonnes-pratiques.md` — ne pas modifier le catalogue unilatéralement.
4. Ajouter/mettre à jour la ligne du dépôt dans `github-audits.csv`, avec des notes (`ID: explication`, séparées par ` | `) pour les cas particuliers.
5. Régénérer les rapports : `./Invoke-RepoCheck.ps1 -Reports -Summary`.

Les IDs de pratiques (`META-01`, `SEC-04`...) doivent rester stables une fois publiés : ils sont les noms de colonnes du CSV.

## Pourquoi le CSV et les rapports ne sont pas suivis par git

`github-audits.csv`, `reports/` et `github-audits-summary.md` sont dans `.gitignore` :

- Le CSV contient les noms des dépôts audités et des notes détaillées sur leurs failles (ex: "pas de secret scanning activé") — publier ça dans le dépôt public `repocheck` reviendrait à documenter publiquement les faiblesses de sécurité d'autres dépôts.
- À terme, une fois `-Audit` implémenté, ce fichier sera de toute façon régénérable à la demande depuis l'API GitHub — inutile de le versionner.

Conséquence directe : ces fichiers n'existent qu'en local, dans ce dossier de travail (`C:\Users\MaurayY\perso\solar`, remote `ymauray/repocheck`). Une session Claude Code démarrée dans un autre clone du dépôt public ne les trouvera pas — il faudra soit repartir de cette machine, soit ré-auditer les dépôts listés ci-dessus.

## Prochaines étapes envisagées

1. Continuer à auditer des dépôts variés (autres langages, autres tailles d'équipe) pour étoffer le catalogue.
2. Une fois le catalogue stabilisé (peu de nouvelles pratiques découvertes sur plusieurs dépôts d'affilée) : implémenter `-Audit`, qui interroge `gh api` pour remplir/mettre à jour `github-audits.csv` automatiquement.
3. Puis un mode `-Fix` qui applique les corrections sûres (réglages GitHub, pas de réécriture de code) directement.
4. **Idée à implémenter avec `-Audit`/`-Fix` (pas avant) : un fichier `.repocheckignore`** dans chaque dépôt audité, listant les IDs de pratiques à ignorer pour ce dépôt (ex: `CI-01` sur un dépôt qui utilise Codemagic plutôt que GitHub Actions — invisible via `gh api`, donc `-Audit` le marquerait `KO` à tort sans cette exclusion explicite). Sert le même rôle que les `NA` posés à la main dans le CSV aujourd'hui, mais lisible par `-Audit` de façon autonome. Ne pas construire ça tant qu'on est en phase catalogue.
