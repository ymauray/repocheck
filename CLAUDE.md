# Contexte projet — RepoCheck

Ce fichier est destiné à toute instance de Claude Code qui reprendrait ce travail (nouvelle session, machine différente, mémoire de conversation non partagée). Pour l'usage de l'outil lui-même, voir `README.md`. Pour les règles de contribution au code, voir `CONTRIBUTING.md`.

## Où on en est

**Phase catalogue : close.** Le référentiel (`github-bonnes-pratiques.md`) est stabilisé à **35 pratiques**, après l'audit manuel de 14 dépôts. Le critère de clôture retenu — plus aucune pratique nouvelle sur plusieurs dépôts d'affilée — a été atteint : les cinq derniers audits (un privé Python, un privé npm, deux dépôts de distribution sans code applicatif, un dépôt de profil) n'ont produit que des confirmations, une note de méthodologie et un ajustement de criticité.

**Phase en cours : implémentation du mode `-Audit`**, qui doit automatiser via `gh api` la collecte faite à la main jusqu'ici, pour remplir et mettre à jour `github-audits.csv`.

Les IDs de pratiques sont désormais **figés** : ce sont les noms de colonnes du CSV. Ajouter ou modifier une pratique reste possible, mais c'est une décision à prendre explicitement avec l'utilisateur — jamais un effet de bord de l'implémentation.

La liste des dépôts déjà audités, leurs scores et les notes détaillées vivent dans `github-audits.csv` (local uniquement, voir plus bas pourquoi). Consulte ce fichier s'il est présent dans le dossier de travail — c'est la seule source de vérité sur l'état d'avancement. `ymauray/repocheck` (ce dépôt) y figure aussi : il s'auto-audite pour dogfooding.

## Méthodologie pour auditer un nouveau dépôt

1. Collecter les données via `gh repo view`, `gh api repos/{owner}/{repo}/...` (contents, branches/{branch}/protection, security_and_analysis, vulnerability-alerts, contents/.github/workflows/*, contributors...).
2. Comparer chaque pratique du catalogue au dépôt réel : `OK`, `KO`, ou `NA` si la pratique ne s'applique pas dans ce contexte (ex: revues obligatoires pour un mainteneur solo).
3. Si un écart intéressant ou une pratique manquante dans le catalogue apparaît (ex: `enforce_admins`, généralisation du fichier d'instructions IA...), en discuter avec l'utilisateur avant de modifier `github-bonnes-pratiques.md` — ne pas modifier le catalogue unilatéralement.
4. Ajouter/mettre à jour la ligne du dépôt dans `github-audits.csv`, avec des notes (`ID: explication`, séparées par ` | `) pour les cas particuliers.
5. Régénérer les rapports : `./Invoke-RepoCheck.ps1 -Reports -Summary`.

Cette méthodologie reste la référence de ce que `-Audit` doit reproduire, et la marche à suivre si un dépôt doit être audité à la main entre-temps.

## Ce que `-Audit` doit savoir (acquis des 14 audits manuels)

Pièges relevés en auditant à la main, que l'automatisation reproduirait silencieusement :

- **`403` n'est pas `404`.** Sur `branches/{branch}/protection`, un dépôt public non protégé renvoie `404`, un dépôt privé en plan gratuit renvoie `403` (« Upgrade to GitHub Pro ») : la pratique y est *indisponible*, pas négligée. De même, `security_and_analysis` vaut `null` sur un privé au lieu d'un objet de statuts. La convention retenue est `KO` dans les deux cas, mais la note du dépôt doit distinguer la cause — voir la section « Dépôts privés » du catalogue.
- **Une CI externe n'est PAS invisible via l'API — contrairement à ce que ce fichier a longtemps affirmé.** Les fournisseurs tiers publient des check-runs, exposés par `repos/{owner}/{repo}/commits/{sha}/check-runs` : le champ `.app.name` vaut `Xcode Cloud`, `Codemagic`, etc. Sur `DuoScribo`, qui n'a aucun workflow GitHub Actions, le check-run `DuoScribo | Default | Archive - iOS` est présent et `success` sur le HEAD de `main`. C'est le signal fiable — `ci_scripts/`, que ce fichier recommandait, est à la fois asymétrique et absent de `DuoScribo`.
- **`actions/workflows` ne liste pas que les fichiers du dépôt.** Sur `DuoScribo`, il renvoie `total_count: 2` alors qu'il n'existe aucun `.github/workflows/` : ce sont des workflows `dynamic/` générés par GitHub (Dependabot Updates, pages-build-deployment). Pour compter les workflows réels, lire `contents/.github/workflows`.
- **Le vrai travail de `-Audit`, c'est le `NA`, pas le `OK`/`KO`.** Sur un dépôt sans code applicatif, jusqu'à 24 des 35 pratiques sont `NA` (dépôt de profil). Un `NA` posé à tort inverse le sens du score, puisque les `NA` sont exclus du calcul et améliorent donc mécaniquement la note.
- **Un score ne se compare qu'à assiette comparable.** C'est pourquoi les rapports affichent le nombre de pratiques applicables à côté du score.
- **Certaines pratiques ne sont pas évaluables par API** et doivent le rester : la justesse d'une description de dépôt, la complétude réelle d'un README. Ne pas tenter de les automatiser par heuristique.

## Pourquoi le CSV et les rapports ne sont pas suivis par git

`github-audits.csv`, `reports/` et `github-audits-summary.md` sont dans `.gitignore` :

- Le CSV contient les noms des dépôts audités et des notes détaillées sur leurs failles (ex: "pas de secret scanning activé") — publier ça dans le dépôt public `repocheck` reviendrait à documenter publiquement les faiblesses de sécurité d'autres dépôts.
- À terme, une fois `-Audit` implémenté, ce fichier sera de toute façon régénérable à la demande depuis l'API GitHub — inutile de le versionner.

Conséquence directe : ces fichiers n'existent que dans le dossier de travail où les audits ont été faits. Deux copies de travail sont connues à ce jour — `C:\Users\MaurayY\perso\solar` (Windows) et `/Volumes/EVO_PRO_1T/Development/repocheck` (macOS, machine sur laquelle les 14 audits ont été menés) — toutes deux sur le remote `ymauray/repocheck`. Une session démarrée dans un autre clone du dépôt public ne trouvera ni le CSV ni les rapports : il faudra soit repartir d'une de ces machines, soit ré-auditer.

## Prochaines étapes

1. **`-Audit` — 30 pratiques sur 35 implémentées.** Les 5 restantes (META-04, META-06, META-09, CI-05, SEC-03) relèvent du jugement et sont saisies à la main ; elles apparaissent en `❔` dans les rapports et sont exclues du score. Reste ouvert : les `NA` de contexte, qu'`-Audit` ne peut pas poser.
2. **`.repocheckignore`** — un fichier dans chaque dépôt audité, listant les IDs de pratiques à ignorer pour ce dépôt (ex : `CI-01` sur un dépôt qui utilise Codemagic plutôt que GitHub Actions, invisible via `gh api`). Il joue le rôle des `NA` posés à la main aujourd'hui, mais de façon lisible par `-Audit`. À construire avec `-Audit`, dont il est le complément indispensable — sans lui, l'automatisation dégradera les résultats par rapport aux audits manuels.
3. **`-Fix`** — appliquer les corrections sûres (réglages GitHub, pas de réécriture de code). Bons candidats déjà identifiés : `default_workflow_permissions` (CI-07), protection de branche, activation des fonctionnalités de sécurité.

Rappel de cadrage : **auditer un dépôt ne sert pas à le réparer.** Les correctifs sur les dépôts audités sont le travail de `-Fix`, pas quelque chose à proposer au fil des audits.
