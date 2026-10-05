# Référentiel de bonnes pratiques — dépôts GitHub

Version : 1.3.0

Chaque pratique reçoit un statut par dépôt :

- `OK` : la pratique est respectée.
- `KO` : elle ne l'est pas.
- `NA` : elle ne s'applique pas à ce dépôt. Un `NA` n'est possible que si la colonne *Évaluation* le prévoit ; à défaut, la pratique est `OK` ou `KO`.

Un **avertissement** signale un écart à surveiller sans pénaliser : il est consigné dans le rapport et le journal, n'entre pas dans le score et ne donne lieu à aucune action dans le plan. Seule la colonne *Évaluation* peut en prévoir un.

Criticité et poids dans le score : 🔴 Haute (4) · 🟠 Moyenne (2) · 🟡 Faible (1) · ⚪ Optionnelle (0,5)

## Typologie des dépôts

Les conditions `NA` reposent sur ces qualifications, à établir au début de chaque audit :

| Qualification | Définition |
|---|---|
| Dépôt sans code | N'héberge aucun code : documentation, contenu, données. |
| Dépôt de distribution | Publie des manifestes de paquets sans code à construire (tap Homebrew, bucket Scoop...). |
| Dépôt déclaratif | Ne produit aucun artefact et n'a aucun outillage local qui laisse des traces. |
| Mainteneur unique | Aucun co-reviewer humain régulier. |

## Métadonnées du dépôt

| ID | Pratique | Criticité | Évaluation | Pourquoi |
|---|---|---|---|---|
| META-01 | Description du dépôt renseignée | 🟡 | | Premier élément lu par un visiteur ; elle résume le projet en une ligne. |
| META-02 | Topics renseignés | 🟡 | | Rend le dépôt trouvable par la recherche GitHub. |
| META-03 | LICENSE présente | 🔴 | | Sans licence explicite, le code est « tous droits réservés » : personne ne peut légalement le réutiliser. |
| META-04 | README complet (installation et usage) | 🟠 | Évalué uniquement sur ce qu'il faut pour installer et utiliser le projet. L'absence d'indications de contribution relève de GOV-01. | Point d'entrée de tout nouveau lecteur. |
| META-05 | Homepage URL renseignée | ⚪ | `NA` si aucun site ni aucune documentation dédiés n'existent. `KO` si un site existe (GitHub Pages actif, déploiement documenté) mais que l'URL n'est pas renseignée, ou si la homepage pointe sur le dépôt lui-même. Tout site publié par le dépôt compte, quel que soit son contenu (par exemple une politique de confidentialité servie par Pages). | Le visiteur doit pouvoir atteindre depuis le dépôt tout site que celui-ci publie. |
| META-06 | `.gitignore` adapté au langage | 🟡 | `NA` sur un dépôt déclaratif. | Évite de committer des artefacts de build ou des fichiers locaux. |
| META-07 | `.editorconfig` présent | 🟡 | | Garantit un style cohérent d'un éditeur et d'un contributeur à l'autre. |
| META-08 | Badges de statut dans le README (build, licence, version...) | ⚪ | `NA` en l'absence de README, puisque META-04 couvre déjà ce manque. | Repère visuel rapide sur l'état du projet. |
| META-09 | Le README documente la chaîne CI/CD réelle, outils externes compris | 🟡 | Il doit aussi indiquer la frontière entre ce que fait la CI du dépôt et ce que fait l'outil externe. | Une release assurée par un outil externe (Xcode Cloud, Codemagic, Bitrise...) ne laisse aucune trace vérifiable via `gh api`. Sans mention dans le README, un lecteur conclut à tort que le projet n'a ni CI ni release. |
| META-10 | `.gitattributes` qui normalise les fins de ligne | 🟡 | `OK` si une règle couvre tous les fichiers texte (`* text=auto`, avec ou sans `eol=lf`). `KO` si le fichier est absent ou ne normalise pas les fins de ligne. Les scripts Windows (`.bat`, `.cmd`), s'il y en a, doivent garder `eol=crlf`. | Les fins de ligne ne dépendent plus de la configuration Git de chaque contributeur (par exemple `core.autocrlf` de Git for Windows) : pas de script shell cassé par du CRLF (`bad interpreter: /bin/bash^M`), pas de diff pollué. |

## Fichiers communautaires et gouvernance

| ID | Pratique | Criticité | Évaluation | Pourquoi |
|---|---|---|---|---|
| GOV-01 | `CONTRIBUTING.md` | 🟡 | `NA` sur un dépôt sans code. | Explique comment proposer une contribution ; utile même en solo, pour les contributeurs externes ponctuels. |
| GOV-02 | `CODE_OF_CONDUCT.md` | ⚪ | Évalué sur le fait et non sur l'intention : son absence sur un dépôt public vaut `KO`. Le mainteneur unique ne justifie pas de `NA`, car le public visé est celui des contributeurs potentiels. | Fixe les attentes envers quiconque ouvre une issue ou une PR. |
| GOV-03 | `SECURITY.md` | 🟠 | `NA` sur un dépôt sans code, où aucune vulnérabilité ne peut être signalée. `KO` si le canal indiqué ne fonctionne pas : signalement privé désactivé alors que le fichier y renvoie, adresse absente ou invalide. | Indique comment signaler une vulnérabilité de façon responsable plutôt que dans une issue publique. |
| GOV-04 | Template(s) d'issue | 🟡 | Reste applicable, même sans code, tant que le dépôt est public et que les issues sont ouvertes. | Standardise les rapports de bug et les demandes de fonctionnalité. |
| GOV-05 | Template de pull request | 🟡 | `NA` sur un dépôt sans code. | Rappelle une checklist (tests, changelog...) à chaque PR. |
| GOV-06 | `CODEOWNERS` | ⚪ | `NA` avec un mainteneur unique. | Sans reviewer dédié, ce fichier ne déclenche aucune demande de revue. |
| GOV-07 | Discussions activées | ⚪ | Évalué sur le fait : des Discussions désactivées valent `KO`. | Canal de questions-réponses distinct des issues. |
| GOV-08 | `SUPPORT.md` | 🟡 | Reste applicable, même sans code, tant que le dépôt est public et que les issues sont ouvertes. | Indique où poser des questions plutôt que d'ouvrir une issue (fichier reconnu par Insights → Community Standards). |

Les fichiers communautaires peuvent se trouver à la racine, dans `.github/` ou dans `docs/`.

## CI/CD et releases

| ID | Pratique | Criticité | Évaluation | Pourquoi |
|---|---|---|---|---|
| CI-01 | CI configurée (build et tests sur push/PR) | 🔴 | `NA` sur un dépôt de distribution. | Détecte les régressions avant qu'elles n'atteignent la branche par défaut. |
| CI-02 | Required status checks sur la branche par défaut | 🔴 | `NA` si CI-01 est `NA`. | Sans eux, une PR peut être mergée même quand la CI échoue. |
| CI-03 | Bloc `permissions:` explicite et minimal dans chaque workflow | 🟠 | `NA` en l'absence de workflow. Le bloc peut être défini au niveau du workflow ou de chaque job. | Sans ce bloc, le workflow hérite des droits par défaut du dépôt, potentiellement trop larges. |
| CI-04 | Actions tierces épinglées à un SHA | 🔴 | Ne vise que les actions hors de l'org `actions/`, qui peuvent rester sur un tag majeur. Le critère est la propriété de l'action, pas la présence de secrets dans le workflow. `NA` en l'absence de workflow. Un SEC-03 en échec ne dégrade pas CI-04. | Un tag `@vN` peut être repointé par le mainteneur de l'action (cf. `tj-actions/changed-files`, mars 2025), alors qu'un SHA est immuable. Pour éviter que les SHA ne vieillissent en silence, SEC-03 doit couvrir l'écosystème `github-actions`. |
| CI-05 | Release automatisée avec versioning sémantique | 🟡 | Une release assurée par un outil externe compte si le dépôt en porte la trace ou la documente (voir META-09). Le format de version n'est disqualifiant que s'il est maîtrisé par le mainteneur et incohérent d'une release à l'autre ; un format imposé par la plateforme (le `MAJOR.MINOR` de l'App Store, par exemple) ne l'est pas. | Assure la traçabilité des versions publiées. |
| CI-06 | Tags de version au format `vX.Y.Z` | 🟡 | Un tag de version ressemble à un numéro de version (`1.2`, `v1.2.3`, `release-1.0`...) ou porte une release. `KO` si un tag de version n'est pas exactement au format `vX.Y.Z`. `NA` en l'absence de tag de version. Les autres tags (jalons, marqueurs...) ne comptent pas dans le statut : ceux qui pointent sur un commit de la branche par défaut font l'objet d'un **avertissement**. | Un tag de version hors du format semver pollue l'historique des releases. |
| CI-07 | Permissions par défaut des workflows en lecture seule | 🟠 | `default_workflow_permissions: read` et `can_approve_pull_request_reviews: false`. | Ce réglage unique couvre tous les workflows, y compris ceux à venir. Avec l'ancien défaut, tout workflow peut écrire dans le dépôt et approuver des PR. |

## Protection de branche

Une règle portée par un ruleset actif ciblant la branche par défaut vaut autant que la même règle en protection de branche classique.

| ID | Pratique | Criticité | Évaluation | Pourquoi |
|---|---|---|---|---|
| BR-01 | Branche par défaut protégée (force-push et suppression interdits) | 🔴 | | Empêche la réécriture ou la perte accidentelle de l'historique partagé. |
| BR-02 | Suppression automatique des branches mergées | ⚪ | | Évite l'accumulation de branches obsolètes. |
| BR-03 | Méthode de merge unique : squash | ⚪ | `OK` seulement si le squash est la seule méthode autorisée. | Un commit par PR donne un historique linéaire et homogène. |
| BR-04 | Revues obligatoires avant merge | ⚪ | `NA` avec un mainteneur unique. | Sans co-reviewer, l'exigence bloquerait chaque merge. |
| BR-05 | Protection appliquée aux administrateurs (`enforce_admins`) | 🔴 | Évalué indépendamment de BR-01 : une branche non protégée échoue aux deux. | Sans cela, un compte admin peut contourner toutes les règles de protection. |

## Sécurité

| ID | Pratique | Criticité | Évaluation | Pourquoi |
|---|---|---|---|---|
| SEC-01 | Dependabot alerts activées | 🔴 | | Sans elles, aucune notification quand une dépendance a une CVE connue. |
| SEC-02 | Dependabot security updates activées | 🔴 | | Corrige les dépendances vulnérables par PR, en complément des alertes. |
| SEC-03 | Dependabot version updates configuré (`.github/dependabot.yml`) | 🟠 | Doit couvrir tous les manifestes du dépôt, y compris ceux de chaque sous-projet, ainsi que l'écosystème `github-actions` dès qu'il y a des workflows. | Maintient les dépendances à jour, même sans vulnérabilité connue. |
| SEC-04 | Secret scanning activé | 🔴 | | Détecte les clés et tokens committés par erreur. |
| SEC-05 | Push protection du secret scanning activée | 🟠 | | Bloque le push d'un secret avant qu'il n'entre dans l'historique. |

## Outillage IA

| ID | Pratique | Criticité | Évaluation | Pourquoi |
|---|---|---|---|---|
| TOOL-01 | `AGENTS.md` présent à la racine, et `CLAUDE.md` à la racine qui l'importe (`@AGENTS.md`) | 🟠 | Attendu sur tout dépôt : jamais `NA`. `KO` si l'un des deux fichiers manque, ou si `CLAUDE.md` renvoie vers `AGENTS.md` par un simple lien au lieu de l'importer. `CLAUDE.md` peut contenir des consignes propres à Claude Code, mais aucune consigne en double avec `AGENTS.md`. Les autres fichiers d'instructions (`GEMINI.md`, `.github/copilot-instructions.md`...) sont tolérés et ne sont pas évalués. | `AGENTS.md` est le format commun aux agents de code : une seule source de consignes évite les divergences. Claude Code ne lit pas `AGENTS.md`, et seul l'import `@AGENTS.md` charge son contenu dans le contexte, ce qu'un lien ne fait pas. |

## Dépôts privés

Sur un dépôt privé en plan gratuit, certaines fonctionnalités sont indisponibles et pas seulement désactivées :

| Signal `gh api` | Dépôt public | Dépôt privé (plan gratuit) |
|---|---|---|
| `branches/{branch}/protection` | `404` : branche non protégée | `403` : « Upgrade to GitHub Pro » |
| `security_and_analysis` | statuts `enabled`/`disabled` | `null` |

Pratiques concernées : BR-01, BR-05, CI-02, SEC-04 et SEC-05.

**Elles valent `KO`, pas `NA`.** La visibilité d'un dépôt est un choix réversible : le rendre public suffit à rendre ces fonctionnalités gratuites, donc l'écart reste réel et corrigeable. Les passer en `NA` donnerait à un dépôt privé un meilleur score qu'à un dépôt public identique. Le rapport d'audit doit préciser la cause pour qu'on ne prenne pas ces `KO` pour de la négligence.

## Score

Score = somme des poids des pratiques `OK` ÷ somme des poids des pratiques `OK` et `KO`, × 100, arrondi à l'entier. Les `NA` sont exclus du calcul. Une pratique couverte par une dérogation reste `KO` dans le score.
