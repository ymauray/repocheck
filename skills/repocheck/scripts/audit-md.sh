#!/usr/bin/env bash
# Génère le contenu d'AUDIT.md à partir des statuts, du référentiel et de la date de l'audit.
# Usage : audit-md.sh <AAAA-MM-JJ> <fichier de statuts>   (ou statuts sur stdin)
# Format d'entrée : celui de score.sh, une ligne « ID STATUT » par pratique.
# Sortie : le fichier sur stdout. Lecture seule : rien n'est écrit sur disque.

set -eu

DIR=$(cd "$(dirname "$0")/.." && pwd)
REF="$DIR/references/BONNES-PRATIQUES.md"

[ $# -ge 1 ] || { echo "Usage : audit-md.sh <AAAA-MM-JJ> [fichier de statuts]" >&2; exit 2; }
DATE=$1
case "$DATE" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "Date invalide : $DATE (attendu AAAA-MM-JJ)" >&2; exit 2 ;;
esac

STATUTS=$(mktemp)
trap 'rm -f "$STATUTS"' EXIT
cat "${2:-/dev/stdin}" > "$STATUTS"

# score.sh valide la liste (pratiques inconnues, doublons, oubli) et calcule le score.
SCORE=$(bash "$DIR/scripts/score.sh" "$STATUTS" | sed -n '1s/^Score : \([0-9]*\)\/100$/\1/p')
[ -n "$SCORE" ] || { echo "Score illisible" >&2; exit 1; }
VERSION=$(sed -n 's/^Version : *//p' "$REF" | head -n 1)

cat <<ENTETE
# Audit repocheck

- **Date** : $DATE
- **Référentiel** : $VERSION
- **Score** : $SCORE/100

ENTETE

# Légende : reprise de la ligne « Criticité et poids dans le score » du référentiel.
awk '
/^Criticité et poids dans le score :/ {
  sub(/^[^:]*: */, "")
  n = split($0, items, / · /)
  print "| Criticité | Niveau | Poids dans le score |"
  print "|---|---|---|"
  for (i = 1; i <= n; i++) {
    if (match(items[i], /^[^ ]+ /) == 0) continue
    emoji = substr(items[i], 1, RLENGTH - 1)
    reste = substr(items[i], RLENGTH + 1)
    p = index(reste, " (")
    printf "| %s | %s | %s |\n", emoji, substr(reste, 1, p - 1), substr(reste, p + 2, length(reste) - p - 2)
  }
  exit
}
' "$REF"

cat <<'LEGENDE'

Le score est la somme des poids des pratiques `OK` divisée par celle des pratiques `OK` et `KO`, sur 100. Les `NA` sont exclus du calcul.

LEGENDE

echo "| Code | Description | Criticité | Résultat |"
echo "|---|---|---|---|"
awk '
FNR == NR { if (NF >= 2) st[$1] = toupper($2); next }
{
  n = split($0, c, "|")
  if (n < 4) next
  id = c[2]; gsub(/^ +| +$/, "", id)
  if (id !~ /^[A-Z]+-[0-9]+$/) next
  desc = c[3]; gsub(/^ +| +$/, "", desc)
  crit = c[4]; gsub(/ /, "", crit)
  printf "| %s | %s | %s | %s |\n", id, desc, crit, st[id]
}
' "$STATUTS" "$REF"
