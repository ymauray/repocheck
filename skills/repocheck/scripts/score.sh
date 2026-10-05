#!/usr/bin/env bash
# Calcule le score d'un audit à partir des statuts, avec les poids lus dans le référentiel.
# Usage : score.sh <fichier de statuts>   (ou statuts sur stdin)
# Format d'entrée : une ligne « ID STATUT » par pratique, STATUT ∈ OK | KO | NA.
# Sortie : score, détail par statut, et contrôle que les 31 pratiques sont présentes une fois.

set -eu

DIR=$(cd "$(dirname "$0")/.." && pwd)
REF="$DIR/references/BONNES-PRATIQUES.md"

awk -v ref="$REF" '
BEGIN {
  # Lignes du référentiel : | ID | Pratique | <emoji> | ...
  while ((getline line < ref) > 0) {
    n = split(line, c, "|")
    if (n < 4) continue
    id = c[2]; crit = c[4]
    gsub(/^ +| +$/, "", id)
    if (id !~ /^[A-Z]+-[0-9]+$/) continue
    if (crit ~ /🔴/) w[id] = 4
    else if (crit ~ /🟠/) w[id] = 2
    else if (crit ~ /🟡/) w[id] = 1
    else if (crit ~ /⚪/) w[id] = 0.5
    else { print "Criticité illisible pour " id > "/dev/stderr"; exit 2 }
    order[++total] = id
  }
}
NF >= 2 {
  id = $1; st = toupper($2)
  if (!(id in w)) { print "ID inconnu : " id > "/dev/stderr"; bad = 1; next }
  if (id in seen) { print "ID en double : " id > "/dev/stderr"; bad = 1; next }
  if (st != "OK" && st != "KO" && st != "NA") { print "Statut invalide pour " id " : " st > "/dev/stderr"; bad = 1; next }
  seen[id] = st; count[st]++
  if (st == "OK") { ok += w[id]; den += w[id] }
  if (st == "KO") den += w[id]
}
END {
  for (i = 1; i <= total; i++) if (!(order[i] in seen)) { print "Pratique non évaluée : " order[i] > "/dev/stderr"; bad = 1 }
  if (bad) exit 1
  score = (den > 0) ? int(100 * ok / den + 0.5) : 100
  printf "Score : %d/100\n", score
  printf "OK : %d · KO : %d · NA : %d (sur %d pratiques)\n", count["OK"], count["KO"], count["NA"], total
  printf "Poids OK : %g / poids évalués : %g\n", ok, den
}
' "${1:-/dev/stdin}"
