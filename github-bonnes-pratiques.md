# Référentiel de bonnes pratiques — dépôts GitHub publics

Catalogue des pratiques évaluées, indépendant des dépôts. Les résultats par dépôt vivent dans `github-audits.csv` (une ligne par dépôt, une colonne par ID de pratique ci-dessous).

Légende criticité : 🔴 Haute · 🟠 Moyenne · 🟡 Faible · ⚪ Optionnel/discutable

## Métadonnées du dépôt

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| META-01 | Description du dépôt renseignée | 🟡 | Premier élément lu par un visiteur, doit résumer le projet en une ligne. |
| META-02 | Topics renseignés | 🟡 | Améliore la découvrabilité via la recherche GitHub. |
| META-03 | LICENSE présente | 🔴 | Sans licence explicite, le code est "tous droits réservés" par défaut, personne ne peut légalement le réutiliser. |
| META-04 | README complet (install et usage) | 🟠 | C'est le point d'entrée de tout nouveau lecteur. S'évalue sur ce qu'il faut pour installer et utiliser le projet : l'absence d'indications de **contribution** relève de GOV-01 et ne doit pas être comptée deux fois, au même titre que META-08 ne recompte pas l'absence de README. |
| META-05 | Homepage URL renseignée | ⚪ | Ne s'évalue que si un site ou une documentation dédiés existent. Sans cible à pointer, la pratique est **sans objet** : `NA`. Un site qui existe — GitHub Pages actif, déploiement documenté — mais dont l'URL n'est pas renseignée vaut `KO`, de même qu'une homepage pointant sur le dépôt lui-même, qui n'oriente vers rien. **Tout site publié par le dépôt compte, quel qu'en soit le contenu** : une politique de confidentialité servie par Pages est une page que le visiteur doit pouvoir atteindre depuis le dépôt, au même titre qu'une documentation. |
| META-06 | `.gitignore` adapté au langage | 🟡 | Évite de committer des artefacts de build ou fichiers locaux. `NA` sur un dépôt purement déclaratif, qui ne produit aucun artefact et n'a pas d'outillage local laissant des traces — il n'y a alors rien à ignorer. |
| META-07 | `.editorconfig` présent | 🟡 | Garantit un style de code cohérent entre éditeurs/contributeurs. |
| META-08 | Badges de statut dans le README (build, licence, version...) | ⚪ | Repère visuel rapide de l'état du projet, purement cosmétique — sans impact sur la qualité ou la sécurité. Sans README du tout, la pratique est **sans objet** : `NA`, car le manquement est déjà compté par META-04 et ne doit pas l'être deux fois. |
| META-09 | Le README documente la chaîne CI/CD réelle, outils externes compris | 🟡 | Une release assurée par un outil externe (Xcode Cloud, Codemagic, Bitrise...) ne laisse aucune trace vérifiable via `gh api` : sans mention dans le README, un lecteur — humain ou automatique — conclut à tort que le projet n'a ni intégration continue ni release. Vaut aussi pour la frontière entre ce que fait la CI du dépôt et ce que fait l'outil externe. |

## Fichiers communautaires / gouvernance

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| GOV-01 | `CONTRIBUTING.md` | 🟡 | Explique comment proposer une contribution, utile même en solo pour des contributeurs externes ponctuels. **Voie contribution de code** : `NA` sur un dépôt qui n'héberge aucun code, où proposer une contribution n'a pas d'objet. |
| GOV-02 | `CODE_OF_CONDUCT.md` | ⚪ | Pose les attentes envers quiconque ouvre une issue ou une PR. Comme GOV-07, s'évalue **sur le fait et non sur l'intention** : sur un dépôt public, l'ajouter produit un effet, donc son absence vaut `KO`. Le `NA` de GOV-06 et BR-04 tient à l'absence de *reviewer* ; il ne se transpose pas ici, où le public visé est celui des contributeurs potentiels, pas des relecteurs désignés. |
| GOV-03 | `SECURITY.md` (politique de sécurité) | 🟠 | Indique comment signaler une vulnérabilité de façon responsable plutôt que par une issue publique. **Voie logiciel** : `NA` sur un dépôt qui n'héberge aucun logiciel, où aucune vulnérabilité ne peut être signalée. |
| GOV-04 | Template(s) d'issue | 🟡 | Standardise les rapports de bug/demandes de fonctionnalité reçus. **Voie interaction** : reste applicable tant que le dépôt est public et les issues ouvertes, même sans code — quelqu'un peut toujours écrire. |
| GOV-05 | Template de pull request | 🟡 | Rappelle une checklist (tests, changelog...) à chaque PR. **Voie contribution de code**, comme GOV-01 : `NA` sur un dépôt sans code. |
| GOV-06 | `CODEOWNERS` | ⚪ | Sans reviewer dédié, un `CODEOWNERS` ne déclenche aucune demande de revue : marquer `NA` en mainteneur unique, **comme BR-04**, dont la condition est identique. Pertinent dès que des reviewers apparaissent. |
| GOV-07 | Discussions activées | ⚪ | Canal Q&A distinct des issues. Le souhait du mainteneur n'étant pas observable, la pratique s'évalue sur le fait et non sur l'intention : Discussions désactivées vaut `KO`. |
| GOV-08 | `SUPPORT.md` (où obtenir de l'aide) | 🟡 | Fichier communautaire reconnu par GitHub (Insights → Community Standards), distinct de `CONTRIBUTING`/`SECURITY` — indique où poser des questions plutôt que d'ouvrir une issue. **Voie interaction**, comme GOV-04 : reste applicable sur un dépôt public sans code. |

## CI/CD et releases

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| CI-01 | CI configurée (build + tests sur push/PR) | 🔴 | Détecte les régressions avant qu'elles n'atteignent la branche par défaut. Aucune CI n'est attendue sur un **dépôt de distribution** (tap Homebrew, bucket Scoop) : il n'y héberge aucun code à construire, la pratique y est `NA`, de même que CI-02 qui en dépend. |
| CI-02 | Required status checks sur la branche protégée | 🔴 | Sans ça, une PR peut être mergée même si la CI échoue — la protection de branche ne sert plus à rien pour la qualité du code. |
| CI-03 | `permissions:` explicite et minimal dans chaque workflow | 🟠 | Sans ce bloc, le workflow hérite du défaut du dépôt, potentiellement plus large que nécessaire. |
| CI-04 | Actions tierces épinglées à un SHA (pas juste un tag mouvant) | 🔴 | Ne vise que les actions **hors org `actions/`** : un tag `@vN` peut être repointé par le mainteneur de l'action (cf. `tj-actions/changed-files`, mars 2025, secrets exfiltrés depuis des milliers de dépôts), un SHA garantit l'immuabilité. Le critère retenu est la **propriété de l'action**, pas la présence de secrets dans le workflow : un workflow peut gagner un secret plus tard sans que personne ne repasse vérifier l'épinglage, alors que le propriétaire de l'action ne change pas. Les actions `actions/*` peuvent rester sur un tag majeur — les compromettre suppose de compromettre GitHub, qui fournit déjà le runner et frappe le `GITHUB_TOKEN`. **Avertissement, non condition** : SEC-03 devrait couvrir l'écosystème `github-actions`, faute de quoi les SHA épinglés pourrissent en silence et l'on troque un risque de chaîne d'approvisionnement contre un risque de version obsolète. Un SEC-03 en échec **ne dégrade pas** CI-04 pour autant — ce sont deux pratiques distinctes, et les confondre en pénaliserait une deux fois. |
| CI-05 | Release automatisée avec versioning sémantique | 🟡 | Facilite la traçabilité des versions publiées. **S'évalue sur l'automatisation de la livraison** : une release assurée par un outil externe (Xcode Cloud, Codemagic) compte, dès lors que le dépôt en porte la trace ou la documente — voir META-09. Le format de version n'est disqualifiant que si le mainteneur le maîtrise et qu'il est incohérent d'une release à l'autre ; un format imposé par la plateforme de distribution, comme le `MAJOR.MINOR` de l'App Store, ne l'est pas. La cohérence des tags Git relève de CI-06. |
| CI-06 | Cohérence des tags Git (uniquement `vX.Y.Z`) | 🟡 | Un tag hors format semver pollue l'historique des releases. |
| CI-07 | Permissions par défaut des workflows en lecture seule (`default_workflow_permissions: read`) | 🟠 | Réglage unique au niveau du dépôt, qui couvre tous les workflows *y compris ceux à venir* — là où CI-03 se vérifie fichier par fichier. L'ancien défaut GitHub (`write` + `can_approve_pull_request_reviews`) donne à tout workflow un droit d'écriture sur le dépôt et le pouvoir d'approuver des PR. |

## Protection de branche

| ID | Pratique | Criticité | Commentaire |
|---|---|---|---|
| BR-01 | Branche par défaut protégée (force-push et suppression interdits) | 🔴 | Empêche la réécriture ou la perte accidentelle de l'historique partagé. |
| BR-02 | Suppression auto des branches mergées | ⚪ | Purement cosmétique/hygiène, évite l'accumulation de branches obsolètes. |
| BR-03 | Méthode de merge unique et cohérente (squash *ou* rebase *ou* merge commit) | ⚪ | Sans convention, l'historique devient hétérogène d'une PR à l'autre. |
| BR-04 | Revues obligatoires avant merge | ⚪ | Non pertinent en mainteneur unique sans co-reviewer humain régulier — marquer N/A dans ce cas. |
| BR-05 | Protection appliquée aussi aux administrateurs (`enforce_admins`) | 🔴 | Sans ça, un compte admin peut contourner force-push interdit, required status checks et toute autre règle de protection configurée. S'évalue **indépendamment de BR-01** : une branche non protégée échoue aux deux, délibérément, car ce sont deux réglages distincts à corriger. |

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

### Dépôts privés : distinguer « non fait » de « impossible »

Sur un dépôt privé en plan gratuit, plusieurs pratiques ne sont pas seulement désactivées : elles sont **indisponibles**. L'API le signale distinctement, et `-Audit` doit s'appuyer sur cette différence plutôt que sur le seul échec de l'appel :

| Signal `gh api` | Dépôt public | Dépôt privé (plan gratuit) |
|---|---|---|
| `branches/{branch}/protection` | `404` — branche non protégée | `403` — « Upgrade to GitHub Pro » |
| `security_and_analysis` | objet de statuts (`enabled`/`disabled`) | `null` |

Pratiques concernées : protection de branche et application aux administrateurs, required status checks, secret scanning et sa push protection.

**Convention retenue : `KO`, pas `NA`.** La visibilité d'un dépôt est un choix réversible, et publier un dépôt suffit à rendre ces fonctionnalités disponibles gratuitement — l'écart reste donc réel et corrigeable. Les passer en `NA` les exclurait du score et donnerait mécaniquement une meilleure note à un dépôt privé qu'à un dépôt public identique, ce qui inverserait le message. La note du dépôt dans le CSV doit en revanche préciser la cause, pour qu'on ne lise pas ces `KO` comme de la négligence.
