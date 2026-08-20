<#
.SYNOPSIS
    Compare les statuts produits par RepoCheck à la référence construite à la main.

.DESCRIPTION
    Instrument de développement pour l'implémentation du mode -Audit, pratique
    par pratique. Compare cellule par cellule un CSV candidat à
    github-audits-reference.csv, et ne rapporte que ce qui diffère.

    Trois états par cellule :
      - conforme       le candidat dit la même chose que la référence
      - divergence     les deux ont une valeur, elles diffèrent
      - non implémenté le candidat n'a rien pour cette pratique

    Seuls les statuts sont comparés, jamais la colonne Notes : le script
    génère des notes factuelles, la référence contient de la prose écrite à
    la main, les deux n'ont pas vocation à coïncider.

    Ne tourne pas en CI : la référence est locale et non versionnée.

.PARAMETER CandidatePath
    CSV à évaluer. Par défaut github-audits.csv à la racine du dépôt.

.PARAMETER ReferencePath
    CSV de référence. Par défaut github-audits-reference.csv à la racine.

.PARAMETER Practice
    Limite la comparaison à une ou plusieurs pratiques (ex: META-01).

.EXAMPLE
    ./tests/Compare-Reference.ps1

.EXAMPLE
    ./tests/Compare-Reference.ps1 -Practice META-01, META-05
#>
[CmdletBinding()]
param(
    [string]$CandidatePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'github-audits.csv'),

    [string]$ReferencePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'github-audits-reference.csv'),

    [string[]]$Practice
)

$ErrorActionPreference = 'Stop'

foreach ($path in @($CandidatePath, $ReferencePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Fichier introuvable : $path"
    }
}

$candidateRows = @(Import-Csv -LiteralPath $CandidatePath -Encoding UTF8)
$referenceRows = @(Import-Csv -LiteralPath $ReferencePath -Encoding UTF8)

if ($referenceRows.Count -eq 0) {
    throw "Référence vide : $ReferencePath"
}

$candidateByRepo = @{}
foreach ($row in $candidateRows) { $candidateByRepo[$row.repo] = $row }

$practiceColumns = @(
    $referenceRows[0].PSObject.Properties.Name |
        Where-Object { $_ -match '^[A-Z]+-\d+$' }
)
if ($Practice) {
    # Via `pwsh -File`, `-Practice META-01,META-05` arrive comme une seule chaîne :
    # on redécoupe pour accepter les deux formes.
    $wanted = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $Practice) {
        foreach ($part in ($item -split ',')) {
            $trimmed = $part.Trim()
            if ($trimmed) { $wanted.Add($trimmed) }
        }
    }

    $practiceColumns = @($practiceColumns | Where-Object { $_ -in $wanted })
    if ($practiceColumns.Count -eq 0) {
        throw "Aucune pratique correspondante : $($wanted -join ', ')"
    }
}

$results = foreach ($column in $practiceColumns) {
    $conforme = 0
    $manquant = 0
    $divergences = [System.Collections.Generic.List[string]]::new()

    foreach ($refRow in $referenceRows) {
        $repo = $refRow.repo
        $refValue = "$($refRow.$column)".Trim().ToUpperInvariant()

        if (-not $candidateByRepo.ContainsKey($repo)) {
            $manquant++
            continue
        }

        $candValue = "$($candidateByRepo[$repo].$column)".Trim().ToUpperInvariant()

        if ([string]::IsNullOrEmpty($candValue)) {
            $manquant++
        }
        elseif ($candValue -eq $refValue) {
            $conforme++
        }
        else {
            $divergences.Add("$repo : script=$candValue, référence=$refValue")
        }
    }

    [pscustomobject]@{
        Practice    = $column
        Conforme    = $conforme
        Manquant    = $manquant
        Divergences = $divergences
        Evalue      = $referenceRows.Count - $manquant
    }
}

$total = $referenceRows.Count

Write-Host ""
Write-Host "Comparaison sur $total dépôt(s) -- candidat : $(Split-Path -Leaf $CandidatePath)"
Write-Host ""
Write-Host ("{0,-10} {1,-12} {2}" -f 'Pratique', 'Conformes', 'Divergences')
Write-Host ("{0,-10} {1,-12} {2}" -f '--------', '---------', '-----------')

foreach ($r in $results) {
    if ($r.Evalue -eq 0) {
        Write-Host ("{0,-10} {1,-12} {2}" -f $r.Practice, '--', 'non implémentée')
        continue
    }

    $score = "$($r.Conforme)/$($r.Evalue)"
    if ($r.Divergences.Count -eq 0) {
        $suffix = ''
        if ($r.Manquant -gt 0) { $suffix = "  ($($r.Manquant) dépôt(s) sans valeur)" }
        Write-Host ("{0,-10} {1,-12} {2}" -f $r.Practice, $score, "--$suffix")
        continue
    }

    Write-Host ("{0,-10} {1,-12} {2}" -f $r.Practice, $score, $r.Divergences[0])
    foreach ($d in $r.Divergences | Select-Object -Skip 1) {
        Write-Host ("{0,-10} {1,-12} {2}" -f '', '', $d)
    }
}

$evaluated = @($results | Where-Object { $_.Evalue -gt 0 })
$totalDivergences = 0
foreach ($r in $evaluated) { $totalDivergences += $r.Divergences.Count }
$clean = @($evaluated | Where-Object { $_.Divergences.Count -eq 0 }).Count

Write-Host ""
Write-Host "Pratiques implémentées : $($evaluated.Count)/$($practiceColumns.Count) -- dont $clean sans divergence -- $totalDivergences divergence(s) au total"
Write-Host ""
