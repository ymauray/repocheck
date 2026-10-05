#!/usr/bin/env bash
# Collecte les signaux bruts nécessaires à l'audit d'un dépôt GitHub.
# Usage : collect.sh [owner/repo]   (par défaut : le dépôt du répertoire courant)
# Sortie : rapport texte sur stdout, une section par signal. Ne modifie rien.
# Dépendance : gh (authentifié). Le filtrage JSON passe par `gh --jq`, sans jq externe.

set -u

REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || {
    echo "Impossible de déterminer le dépôt : passer owner/repo en argument." >&2
    exit 2
  }
fi

# Appelle gh api ; en cas d'échec, affiche le code HTTP au lieu d'interrompre la collecte.
api() {
  local out rc
  out=$(gh api "$@" 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    local code
    code=$(printf '%s' "$out" | grep -o 'HTTP [0-9]*' | tail -1)
    echo "ÉCHEC ${code:-?} : $(printf '%s' "$out" | head -1)"
  elif [ -z "$out" ]; then
    echo "(succès, réponse vide ou liste vide)"
  else
    printf '%s\n' "$out"
  fi
}

raw() {
  api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/$1?ref=$BRANCH"
}

section() { printf '\n===== [repocheck] %s =====\n\n' "$1"; }

echo "# Collecte repocheck — $REPO"
echo "Date : $(date -u +%Y-%m-%dT%H:%M:%SZ)"

section "Dépôt"
api "repos/$REPO" --jq '{
  full_name, description, homepage, topics, visibility, private, fork, archived,
  default_branch, has_issues, has_discussions, has_pages, has_wiki,
  license: .license.spdx_id,
  delete_branch_on_merge, allow_squash_merge, allow_merge_commit, allow_rebase_merge,
  security_and_analysis, owner_type: .owner.type
}'

BRANCH=$(gh api "repos/$REPO" --jq .default_branch 2>/dev/null)
if [ -z "$BRANCH" ]; then
  echo "Dépôt inaccessible : arrêt de la collecte." >&2
  exit 1
fi

section "Collaborateurs (login, rôle)"
api "repos/$REPO/collaborators" --paginate --jq '.[] | "\(.login) \(.role_name)"'

section "Arborescence (racine, puis fichiers pertinents)"
TREE_RAW=$(gh api "repos/$REPO/git/trees/$BRANCH?recursive=1" --jq '(.truncated|tostring), (.tree[] | select(.type=="blob") | .path)' 2>/dev/null)
TRUNC=$(printf '%s\n' "$TREE_RAW" | head -1)
TREE=$(printf '%s\n' "$TREE_RAW" | tail -n +2)
echo "Arbre tronqué par l'API : ${TRUNC:-inconnu}"
echo "Nombre de fichiers : $(printf '%s\n' "$TREE" | grep -c . )"
echo
echo "### Racine"
gh api "repos/$REPO/contents?ref=$BRANCH" --jq '.[] | "\(.type)\t\(.name)"' 2>/dev/null
echo
echo "### Fichiers de configuration, communautaires et manifestes"
printf '%s\n' "$TREE" | grep -v -E '(^|/)(node_modules|vendor|Pods|\.venv|dist|build)/' | grep -E -i \
  '(^|/)(readme[^/]*|license[^/]*|licence[^/]*|copying[^/]*|contributing[^/]*|code_of_conduct[^/]*|security[^/]*|support[^/]*|codeowners|\.gitignore|\.gitattributes|\.editorconfig|claude\.md|agents\.md|gemini\.md|copilot-instructions\.md|\.cursorrules|dependabot\.ya?ml|pull_request_template[^/]*|package\.json|requirements[^/]*\.txt|pyproject\.toml|pipfile|setup\.py|go\.mod|cargo\.toml|gemfile|composer\.json|pom\.xml|build\.gradle(\.kts)?|[^/]*\.csproj|[^/]*\.sln|packages\.config|package\.swift|podfile|pubspec\.yaml|dockerfile|docker-compose[^/]*|mix\.exs|[^/]*\.tf|\.gitmodules|cname|_config\.yml|mkdocs\.yml|codemagic\.yaml|bitrise\.yml|\.releaserc[^/]*|release-please[^/]*|\.goreleaser[^/]*)$|^\.github/|^\.ci_scripts/|^ci_scripts/|^Casks/|^Formula/|^bucket/'

section "README"
echo "~~~~markdown"; api "repos/$REPO/readme" -H "Accept: application/vnd.github.raw" | head -n 400; echo "~~~~"

section "Workflows"
WORKFLOWS=$(printf '%s\n' "$TREE" | grep -E '^\.github/workflows/[^/]+\.ya?ml$')
if [ -z "$WORKFLOWS" ]; then
  echo "(aucun workflow)"
else
  for wf in $WORKFLOWS; do
    echo "### $wf"
    echo '```yaml'
    raw "$wf"
    echo '```'
  done
fi

section "CLAUDE.md (TOOL-01 : doit importer @AGENTS.md)"
if printf '%s\n' "$TREE" | grep -qxF 'CLAUDE.md'; then raw CLAUDE.md; else echo "(absent)"; fi
echo
if printf '%s\n' "$TREE" | grep -qxF 'AGENTS.md'; then echo "AGENTS.md : présent à la racine"; else echo "AGENTS.md : absent de la racine"; fi

section ".gitattributes (META-10)"
if printf '%s\n' "$TREE" | grep -qxF '.gitattributes'; then raw .gitattributes; else echo "(absent)"; fi
echo
echo "Scripts Windows (.bat/.cmd) : $(printf '%s\n' "$TREE" | grep -c -i -E '\.(bat|cmd)$')"

section "dependabot.yml"
DEP=$(printf '%s\n' "$TREE" | grep -E '^\.github/dependabot\.ya?ml$' | head -1)
if [ -n "$DEP" ]; then raw "$DEP"; else echo "(absent)"; fi

section "Protection de branche classique ($BRANCH)"
api "repos/$REPO/branches/$BRANCH/protection"

section "Règles effectives sur $BRANCH (rulesets inclus)"
api "repos/$REPO/rules/branches/$BRANCH"

section "Rulesets du dépôt"
api "repos/$REPO/rulesets" --jq '.[] | {id, name, target, enforcement}'

section "Permissions par défaut des workflows"
api "repos/$REPO/actions/permissions/workflow"

section "Dependabot alerts (vulnerability-alerts : succès = activées, 404 = désactivées)"
api "repos/$REPO/vulnerability-alerts"

section "Dependabot security updates (automated-security-fixes)"
api "repos/$REPO/automated-security-fixes"

section "Signalement privé de vulnérabilités"
api "repos/$REPO/private-vulnerability-reporting"

section "Tags (100 premiers)"
TAGS=$(gh api "repos/$REPO/tags?per_page=100" --jq '.[].name' 2>/dev/null)
if [ -z "$TAGS" ]; then
  echo "(aucun tag)"
else
  # Pour chaque tag : est-il atteignable depuis la branche par défaut ? (compare : behind/identical = ancêtre de la branche)
  for t in $TAGS; do
    st=$(gh api "repos/$REPO/compare/$BRANCH...$t" --jq .status 2>/dev/null)
    case "$st" in
      behind|identical) where="sur $BRANCH" ;;
      "") where="position inconnue" ;;
      *) where="hors de $BRANCH ($st)" ;;
    esac
    printf '%s	%s
' "$t" "$where"
  done
fi

section "Releases (10 dernières)"
api "repos/$REPO/releases?per_page=10" --jq '.[] | "\(.tag_name)\t\(.name)\t\(.published_at)\tprerelease=\(.prerelease)"'

section "GitHub Pages"
api "repos/$REPO/pages" --jq '{html_url, status, build_type, cname}'

section "Checks du dernier commit de $BRANCH (noms utilisables comme required status checks)"
SHA=$(gh api "repos/$REPO/commits/$BRANCH" --jq .sha 2>/dev/null)
api "repos/$REPO/commits/$SHA/check-runs" --jq '.check_runs[] | "\(.name)\t\(.conclusion)\tapp=\(.app.slug)"'
api "repos/$REPO/commits/$SHA/status" --jq '.statuses[] | "\(.context)\t\(.state)"'

section "Fin de collecte"
