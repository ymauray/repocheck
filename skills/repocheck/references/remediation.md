# Remédiation par pratique

Chaque action est de l'un de ces deux types :

- **API** : réglage GitHub modifié directement via `gh`. Avant chaque modification, relever l'état existant et le consigner dans le journal, car c'est ce qui permet de revenir en arrière.
- **PR** : création ou modification de fichiers, toujours par une pull request dans le dépôt cible, jamais par un push direct sur la branche par défaut.

Notations : `$R` = `owner/repo`, `$B` = branche par défaut.

## Règles générales

- Ne jamais écraser un fichier existant. S'il existe mais ne suffit pas, le compléter dans la PR et expliquer la modification.
- Adapter chaque fichier au dépôt (langage, nom, outils réels). Les modèles de `templates/` sont des points de départ, pas du copier-coller.
- Un dépôt archivé est en lecture seule : n'y proposer aucune action, seulement l'audit.
- Actions **irréversibles** (suppression de tags, réécriture de l'historique) : ne jamais les inclure dans un lot. Les proposer une par une, avec une confirmation explicite.

## Métadonnées

| ID | Type | Action |
|---|---|---|
| META-01 | API | `gh repo edit $R --description "..."`. Rédiger la description à partir du README et la faire valider. |
| META-02 | API | `gh repo edit $R --add-topic t1,t2`. Proposer 3 à 8 topics (langage, domaine, plateforme). |
| META-03 | PR | `LICENSE`. **Demander quelle licence choisir**, ne jamais en imposer une. Le texte se récupère avec `gh api licenses/<spdx> --jq .body`, en complétant l'année et le titulaire. |
| META-04 | PR | Compléter le README : prérequis, installation, usage minimal. Ne rien inventer, s'appuyer sur le code et les manifestes. |
| META-05 | API | `gh repo edit $R --homepage <url>` (par exemple l'URL Pages donnée par `gh api repos/$R/pages --jq .html_url`). |
| META-06 | PR | `.gitignore` adapté au langage, à partir de `gh api gitignore/templates/<Lang> --jq .source`. |
| META-07 | PR | `.editorconfig` (modèle dans `templates/`), à aligner sur le style existant du code : indentation, fins de ligne. |
| META-08 | PR | Badges en tête du README : statut du workflow CI (`https://github.com/$R/actions/workflows/<fichier>/badge.svg`), licence, dernière release. |
| META-09 | PR | Section « Intégration continue et releases » dans le README : ce que fait chaque workflow, quel outil externe produit les releases, et où passe la frontière entre les deux. **Demander à l'utilisateur** quels outils externes il utilise, car ils sont invisibles via l'API. |
| META-10 | PR | `.gitattributes` (modèle) : `* text=auto eol=lf`, plus `*.bat text eol=crlf` et `*.cmd text eol=crlf` si le dépôt en contient. Compléter un fichier existant sans retirer ses règles (`binary`, `linguist-*`, LFS...). Dans le **même commit**, lancer `git add --renormalize .` pour que les fichiers déjà versionnés en CRLF soient convertis ; signaler dans la PR le nombre de fichiers touchés par la renormalisation. |

## Gouvernance

| ID | Type | Action |
|---|---|---|
| GOV-01 | PR | `CONTRIBUTING.md` (modèle) : commandes de build et de test réelles, convention de branche, merge en squash. |
| GOV-02 | PR | `CODE_OF_CONDUCT.md` : Contributor Covenant 2.1, avec le moyen de contact du mainteneur (**à demander**). |
| GOV-03 | PR | `SECURITY.md` (modèle) : signalement par *Private vulnerability reporting*, à activer avec `gh api -X PUT repos/$R/private-vulnerability-reporting`. Cette activation est une action API à consigner séparément. |
| GOV-04 | PR | `.github/ISSUE_TEMPLATE/bug_report.yml`, `feature_request.yml` et `config.yml` (modèles). |
| GOV-05 | PR | `.github/pull_request_template.md` (modèle). |
| GOV-06 | PR | `.github/CODEOWNERS` : `* @<reviewer>`. |
| GOV-07 | API | `gh repo edit $R --enable-discussions` |
| GOV-08 | PR | `.github/SUPPORT.md` (modèle) : renvoie vers les Discussions si elles sont activées, sinon vers les issues. |

## CI/CD

| ID | Type | Action |
|---|---|---|
| CI-01 | PR | `.github/workflows/ci.yml` : build et tests sur `push` et `pull_request` vers `$B`, avec `permissions: contents: read`. S'appuyer sur les commandes de build et de test réelles du projet. **Vérifier que le workflow passe** sur la PR avant de proposer CI-02. |
| CI-02 | API | Voir « Protection de branche » plus bas. Les `contexts` doivent être des noms de checks **réellement produits** par la CI (section « Checks du dernier commit » de la collecte). Un check requis qui ne tourne jamais bloque tous les merges. |
| CI-03 | PR | Ajouter `permissions:` en tête de chaque workflow, au minimum `contents: read`, et n'élargir que par job si nécessaire (par exemple `contents: write` pour publier une release). |
| CI-04 | PR | Remplacer `uses: owner/action@vX` par `uses: owner/action@<sha> # vX.Y.Z`. Pour obtenir le SHA : `gh api repos/<owner>/<action>/git/ref/tags/<tag> --jq .object`. Si `type` vaut `tag` (tag annoté), suivre avec `gh api repos/<owner>/<action>/git/tags/<sha> --jq .object.sha`. Ne pas toucher aux actions `actions/*`. |
| CI-05 | PR | Proposer un workflow de release adapté à l'écosystème (release-please, goreleaser, publication sur tag `v*`...). C'est un changement de processus : **présenter les options et laisser choisir**. |
| CI-06 | — | Ne rien supprimer d'office. Lister les tags hors format, puis proposer pour chacun de le garder ou de le supprimer (`gh api -X DELETE repos/$R/git/refs/tags/<tag>`, **irréversible**, une confirmation par tag). Un tag lié à une release publiée doit toujours être conservé. Il est aussi possible de documenter la convention pour les tags futurs. |
| CI-07 | API | `gh api -X PUT repos/$R/actions/permissions/workflow -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false`. Avant de l'appliquer, vérifier que chaque workflow qui écrit (release, push de tags) déclare ses propres `permissions:` (CI-03), sinon il cassera. |

## Protection de branche (BR-01, BR-05, CI-02)

`PUT .../protection` **remplace toute la configuration**. Il faut donc :

1. Relever l'existant avec `gh api repos/$R/branches/$B/protection` et le consigner tel quel dans le journal.
2. Construire le corps complet en conservant les réglages existants et en ne modifiant que ce qui est validé :

```json
{
  "required_status_checks": { "strict": false, "contexts": ["<check 1>", "<check 2>"] },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

3. Écrire ce corps dans un fichier temporaire du scratchpad et l'appliquer avec `gh api -X PUT repos/$R/branches/$B/protection --input <fichier>`.

Si aucun check n'est encore disponible (pas de CI), mettre `"required_status_checks": null`. CI-02 reste alors `KO`.

**Impact à signaler avant validation** : avec `enforce_admins: true` et des checks requis, un push direct sur `$B` est refusé tant que les checks ne sont pas passés sur ce commit. Le mainteneur doit alors passer par des PR. C'est le but recherché, mais cela change ses habitudes.

Si le dépôt utilise des rulesets plutôt que la protection classique, modifier le ruleset existant (`gh api repos/$R/rulesets/<id>`) au lieu d'ajouter une protection classique en parallèle.

Sur un dépôt privé en plan gratuit (`403`), ces actions sont impossibles. Le dire, sans proposer de contournement : la seule solution est de passer le dépôt en public ou de souscrire GitHub Pro, et c'est la décision de l'utilisateur.

## Réglages de merge (BR-02, BR-03)

| ID | Type | Action |
|---|---|---|
| BR-02 | API | `gh repo edit $R --delete-branch-on-merge` |
| BR-03 | API | `gh repo edit $R --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false` |
| BR-04 | API | Dans le corps de protection : `"required_pull_request_reviews": {"required_approving_review_count": 1}`. Seulement s'il y a des reviewers. |

## Sécurité

| ID | Type | Action |
|---|---|---|
| SEC-01 | API | `gh api -X PUT repos/$R/vulnerability-alerts` |
| SEC-02 | API | `gh api -X PUT repos/$R/automated-security-fixes` (nécessite SEC-01) |
| SEC-03 | PR | `.github/dependabot.yml` : une entrée par écosystème et par répertoire contenant un manifeste, plus `github-actions` sur `/` s'il y a des workflows. Fréquence hebdomadaire. Compléter le fichier s'il existe déjà. |
| SEC-04 | API | `gh api -X PATCH repos/$R --input <fichier>` avec `{"security_and_analysis":{"secret_scanning":{"status":"enabled"}}}` |
| SEC-05 | API | Idem avec `"secret_scanning_push_protection":{"status":"enabled"}`. SEC-04 et SEC-05 peuvent passer dans le même appel. |

## Outillage IA

| ID | Type | Action |
|---|---|---|
| TOOL-01 | PR | **`AGENTS.md` absent** : s'il existe un fichier d'instructions (`CLAUDE.md` complet, `GEMINI.md`...), en reprendre le contenu dans `AGENTS.md` (`git mv` si c'est le seul, pour garder l'historique) en retirant ce qui vise un outil précis. Sinon, rédiger un `AGENTS.md` concis à partir du contenu réel du dépôt : description, commandes de build, de test et de lint, conventions, architecture. **`CLAUDE.md` absent ou sans import** : partir du modèle `templates/CLAUDE.md`. Si `CLAUDE.md` contient des consignes, déplacer dans `AGENTS.md` celles qui sont communes et ne garder que celles propres à Claude Code. Ne pas toucher aux autres fichiers d'instructions. |

## Mise en œuvre d'une PR

1. Cloner dans le scratchpad : `gh repo clone $R <scratchpad>/<repo>`.
2. Créer la branche `repocheck/<AAAA-MM-JJ>`.
3. Faire **un commit par pratique**, avec un message de la forme `chore(repocheck): <ID> — <résumé>`, suivi des lignes d'attribution en vigueur.
4. `git push -u origin <branche>`, puis `gh pr create --base $B --title "Mise en conformité repocheck (<date>)" --body <corps>`. Le corps liste les pratiques traitées (ID, criticité, résumé) et renvoie au journal.
5. Ne pas merger la PR : c'est à l'utilisateur de la relire et de la merger.
