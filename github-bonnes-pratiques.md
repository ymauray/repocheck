# Référentiel de bonnes pratiques — dépôts GitHub publics

Catalogue des pratiques évaluées, indépendant des dépôts. Les résultats par dépôt vivent dans `github-audits.csv` (une ligne par dépôt, une colonne par ID de pratique ci-dessous).

Légende criticité : 🔴 Haute · 🟠 Moyenne · 🟡 Faible · ⚪ Optionnel/discutable

## Métadonnées du dépôt

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| META-01 | Description du dépôt renseignée | 🟡 | Premier élément lu par un visiteur, doit résumer le projet en une ligne. |
| META-02 | Topics renseignés | 🟡 | Améliore la découvrabilité via la recherche GitHub. |
| META-03 | LICENSE présente | 🔴 | Sans licence explicite, le code est "tous droits réservés" par défaut, personne ne peut légalement le réutiliser. |
| META-04 | README complet (install, usage, contribution) | 🟠 | C'est le point d'entrée de tout nouveau lecteur ou contributeur. |
| META-05 | Homepage URL renseignée | ⚪ | Utile seulement si un site/doc dédié existe. |
| META-06 | `.gitignore` adapté au langage | 🟡 | Évite de committer des artefacts de build ou fichiers locaux. |
| META-07 | `.editorconfig` présent | 🟡 | Garantit un style de code cohérent entre éditeurs/contributeurs. |
| META-08 | Badges de statut dans le README (build, licence, version...) | ⚪ | Repère visuel rapide de l'état du projet, purement cosmétique — sans impact sur la qualité ou la sécurité. |
| META-09 | Le README documente la chaîne CI/CD réelle, outils externes compris | 🟡 | Une release assurée par un outil externe (Xcode Cloud, Codemagic, Bitrise...) ne laisse aucune trace vérifiable via `gh api` : sans mention dans le README, un lecteur — humain ou automatique — conclut à tort que le projet n'a ni intégration continue ni release. Vaut aussi pour la frontière entre ce que fait la CI du dépôt et ce que fait l'outil externe. |

## Fichiers communautaires / gouvernance

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| GOV-01 | `CONTRIBUTING.md` | 🟡 | Explique comment proposer une contribution, utile même en solo pour des contributeurs externes ponctuels. |
| GOV-02 | `CODE_OF_CONDUCT.md` | ⚪ | Surtout pertinent si le projet vise une communauté active de contributeurs. |
| GOV-03 | `SECURITY.md` (politique de sécurité) | 🟠 | Indique comment signaler une vulnérabilité de façon responsable plutôt que par une issue publique. |
| GOV-04 | Template(s) d'issue | 🟡 | Standardise les rapports de bug/demandes de fonctionnalité reçus. |
| GOV-05 | Template de pull request | 🟡 | Rappelle une checklist (tests, changelog...) à chaque PR. |
| GOV-06 | `CODEOWNERS` | ⚪ | Peu utile en mainteneur unique, pertinent si des reviewers dédiés apparaissent. |
| GOV-07 | Discussions activées | ⚪ | Pertinent seulement si un canal Q&A/communauté est souhaité. |
| GOV-08 | `SUPPORT.md` (où obtenir de l'aide) | 🟡 | Fichier communautaire reconnu par GitHub (Insights → Community Standards), distinct de `CONTRIBUTING`/`SECURITY` — indique où poser des questions plutôt que d'ouvrir une issue. |

## CI/CD et releases

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| CI-01 | CI configurée (build + tests sur push/PR) | 🔴 | Détecte les régressions avant qu'elles n'atteignent la branche par défaut. |
| CI-02 | Required status checks sur la branche protégée | 🔴 | Sans ça, une PR peut être mergée même si la CI échoue — la protection de branche ne sert plus à rien pour la qualité du code. |
| CI-03 | `permissions:` explicite et minimal dans chaque workflow | 🟠 | Sans ce bloc, le workflow hérite du défaut du dépôt, potentiellement plus large que nécessaire. |
| CI-04 | Actions tierces épinglées à un SHA (pas juste un tag mouvant) | 🟠 | Ne vise que les actions **hors org `actions/`** : un tag `@vN` peut être repointé par le mainteneur de l'action (cf. `tj-actions/changed-files`, mars 2025, secrets exfiltrés depuis des milliers de dépôts), un SHA garantit l'immuabilité. Le critère retenu est la **propriété de l'action**, pas la présence de secrets dans le workflow : un workflow peut gagner un secret plus tard sans que personne ne repasse vérifier l'épinglage, alors que le propriétaire de l'action ne change pas. Les actions `actions/*` peuvent rester sur un tag majeur — les compromettre suppose de compromettre GitHub, qui fournit déjà le runner et frappe le `GITHUB_TOKEN`. **Prérequis** : SEC-03 doit couvrir l'écosystème `github-actions`, faute de quoi les SHA épinglés pourrissent en silence et l'on troque un risque de chaîne d'approvisionnement contre un risque de version obsolète. |
| CI-05 | Release automatisée avec versioning sémantique | 🟡 | Facilite la traçabilité des versions publiées. |
| CI-06 | Cohérence des tags Git (uniquement `vX.Y.Z`) | 🟡 | Un tag hors format semver pollue l'historique des releases. |
| CI-07 | Permissions par défaut des workflows en lecture seule (`default_workflow_permissions: read`) | 🟠 | Réglage unique au niveau du dépôt, qui couvre tous les workflows *y compris ceux à venir* — là où CI-03 se vérifie fichier par fichier. L'ancien défaut GitHub (`write` + `can_approve_pull_request_reviews`) donne à tout workflow un droit d'écriture sur le dépôt et le pouvoir d'approuver des PR. |

## Protection de branche

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| BR-01 | Branche par défaut protégée (force-push et suppression interdits) | 🔴 | Empêche la réécriture ou la perte accidentelle de l'historique partagé. |
| BR-02 | Suppression auto des branches mergées | ⚪ | Purement cosmétique/hygiène, évite l'accumulation de branches obsolètes. |
| BR-03 | Méthode de merge unique et cohérente (squash *ou* rebase *ou* merge commit) | ⚪ | Sans convention, l'historique devient hétérogène d'une PR à l'autre. |
| BR-04 | Revues obligatoires avant merge | ⚪ | Non pertinent en mainteneur unique sans co-reviewer humain régulier — marquer N/A dans ce cas. |
| BR-05 | Protection appliquée aussi aux administrateurs (`enforce_admins`) | 🔴 | Sans ça, un compte admin peut contourner force-push interdit, required status checks et toute autre règle de protection configurée. |

## Sécurité (fonctionnalités gratuites sur dépôt public)

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| SEC-01 | Dependabot alerts (vulnerability alerts) activées | 🔴 | Sans ça, aucune notification si une dépendance a une CVE connue. |
| SEC-02 | Dependabot security updates activées | 🔴 | Corrige automatiquement les dépendances vulnérables via PR, complément direct des alertes. |
| SEC-03 | Dependabot version updates configuré (`dependabot.yml`) | 🟠 | Maintient les dépendances à jour même hors vulnérabilité connue — doit couvrir tous les manifests du repo (chaque sous-projet en cas de repo multi-projets, pas seulement la racine). |
| SEC-04 | Secret scanning activé | 🔴 | Détecte les clés/tokens committés par erreur — gratuit et sans effort sur un dépôt public. |
| SEC-05 | Secret scanning push protection activé | 🟠 | Bloque le push d'un secret avant même qu'il n'entre dans l'historique, complément du scan a posteriori. |

## Outillage / IA

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| TOOL-01 | Fichier d'instructions IA présent et au bon emplacement (`CLAUDE.md`, `.github/copilot-instructions.md`, `GEMINI.md`, selon l'outil utilisé) | 🟠 | Attendu sur **tout** dépôt : l'absence de fichier d'instructions vaut `KO`, jamais `NA`. Un fichier mal placé (ex. Copilot à la racine au lieu de `.github/`) est ignoré silencieusement par l'outil — vérifier l'emplacement canonique de chaque assistant IA réellement utilisé dans le repo. |

---

## Notes

- Statuts possibles dans `github-audits.csv` : `OK` (respectée), `KO` (non respectée), `NA` (non applicable à ce dépôt, ex. BR-04 en solo).
- Un score par dépôt sera calculé (pondéré par criticité) directement depuis le CSV plutôt que maintenu à la main.
- Points encore à trancher avant d'écrire le script : méthode de merge à standardiser (squash seul ?), faut-il un `CODE_OF_CONDUCT.md` systématique.
