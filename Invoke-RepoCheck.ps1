<#
.SYNOPSIS
    Audit des dépôts GitHub par rapport au référentiel de bonnes pratiques.

.DESCRIPTION
    Fusionne le catalogue de pratiques (github-bonnes-pratiques.md) et les
    résultats par dépôt (github-audits.csv) pour produire un rapport
    Markdown par dépôt.

.PARAMETER Reports
    Génère un fichier de rapport Markdown par dépôt (un fichier par ligne
    du CSV) dans -OutputDir.

.PARAMETER Summary
    Génère un rapport global (un seul fichier) listant tous les dépôts
    traités, triés par score croissant (les pires en premier).

.PARAMETER Repo
    Limite le traitement à un ou plusieurs dépôts (ex: owner/repo).
    Par défaut, tous les dépôts du CSV sont traités.

.PARAMETER CatalogPath
    Chemin du catalogue de pratiques. Par défaut github-bonnes-pratiques.md
    à côté du script.

.PARAMETER CsvPath
    Chemin de la matrice de résultats. Par défaut github-audits.csv à côté
    du script.

.PARAMETER OutputDir
    Dossier de sortie des rapports par dépôt. Par défaut ./reports à côté
    du script.

.PARAMETER SummaryPath
    Chemin du rapport global. Par défaut github-audits-summary.md à côté
    du script.

.EXAMPLE
    ./Invoke-RepoCheck.ps1 -Reports

.EXAMPLE
    ./Invoke-RepoCheck.ps1 -Reports -Summary

.EXAMPLE
    ./Invoke-RepoCheck.ps1 -Reports -Repo owner/repo
#>
[CmdletBinding()]
param(
    [switch]$Reports,

    [switch]$Summary,

    [string[]]$Repo,

    [string]$CatalogPath = (Join-Path $PSScriptRoot 'github-bonnes-pratiques.md'),

    [string]$CsvPath = (Join-Path $PSScriptRoot 'github-audits.csv'),

    [string]$OutputDir = (Join-Path $PSScriptRoot 'reports'),

    [string]$SummaryPath = (Join-Path $PSScriptRoot 'github-audits-summary.md')
)

$ErrorActionPreference = 'Stop'

$WeightByEmoji = @{
    '🔴' = 4
    '🟠' = 3
    '🟡' = 2
    '⚪' = 1
}

$LabelByEmoji = @{
    '🔴' = 'Haute'
    '🟠' = 'Moyenne'
    '🟡' = 'Faible'
    '⚪' = 'Optionnel'
}

$StatusSymbol = @{
    'OK' = '✅'
    'KO' = '❌'
    'NA' = '➖'
}

function Read-Catalog {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Catalogue introuvable : $Path"
    }

    $entries = [System.Collections.Generic.List[pscustomobject]]::new()
    $currentCategory = $null

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ($line -match '^##\s+(?<category>.+)$') {
            $currentCategory = $Matches.category.Trim()
            continue
        }

        if ($line -match '^\|\s*(?<id>[A-Z]+-\d+)\s*\|\s*(?<practice>.+?)\s*\|\s*(?<crit>[^\|]+?)\s*\|\s*(?<comment>.+?)\s*\|\s*$') {
            $entries.Add([pscustomobject]@{
                Id          = $Matches.id
                Category    = $currentCategory
                Practice    = $Matches.practice
                Criticality = $Matches.crit
                Weight      = $(if ($WeightByEmoji.ContainsKey($Matches.crit)) { $WeightByEmoji[$Matches.crit] } else { 1 })
                Comment     = $Matches.comment
            })
        }
    }

    if ($entries.Count -eq 0) {
        throw "Aucune pratique trouvée dans le catalogue : $Path"
    }

    return $entries
}

function Read-Notes {
    param([string]$RawNotes)

    $map = @{}
    if ([string]::IsNullOrWhiteSpace($RawNotes)) {
        return $map
    }

    foreach ($segment in ($RawNotes -split '\|')) {
        $trimmed = $segment.Trim()
        if ($trimmed -match '^(?<id>[A-Z]+-\d+):\s*(?<note>.+)$') {
            $map[$Matches.id] = $Matches.note.Trim()
        }
    }

    return $map
}

function New-RepoReport {
    param(
        [Parameter(Mandatory)]$CatalogEntries,
        [Parameter(Mandatory)]$AuditRow
    )

    $notes = Read-Notes -RawNotes $AuditRow.Notes
    $repo = $AuditRow.repo

    $rows = foreach ($entry in $CatalogEntries) {
        $status = $AuditRow.PSObject.Properties[$entry.Id].Value
        if ([string]::IsNullOrWhiteSpace($status)) { $status = 'KO' }
        $status = $status.Trim().ToUpperInvariant()

        [pscustomobject]@{
            Id          = $entry.Id
            Category    = $entry.Category
            Practice    = $entry.Practice
            Criticality = $entry.Criticality
            Weight      = $entry.Weight
            Comment     = $entry.Comment
            Status      = $status
            Note        = $(if ($notes.ContainsKey($entry.Id)) { $notes[$entry.Id] } else { $null })
        }
    }

    $applicable = $rows | Where-Object { $_.Status -ne 'NA' }
    $applicableCount = @($applicable).Count
    $totalCount = @($rows).Count
    $earnedWeight = ($applicable | Where-Object { $_.Status -eq 'OK' } | Measure-Object -Property Weight -Sum).Sum
    $totalWeight = ($applicable | Measure-Object -Property Weight -Sum).Sum
    $score = 0
    if ($totalWeight -gt 0) {
        $score = [Math]::Round(($earnedWeight / $totalWeight) * 100)
    }

    $breakdown = foreach ($emoji in @('🔴', '🟠', '🟡', '⚪')) {
        $subset = $applicable | Where-Object { $_.Criticality -eq $emoji }
        if ($subset.Count -eq 0) { continue }
        [pscustomobject]@{
            Criticality = $emoji
            Label       = $LabelByEmoji[$emoji]
            Weight      = $WeightByEmoji[$emoji]
            Ok          = ($subset | Where-Object { $_.Status -eq 'OK' }).Count
            Total       = $subset.Count
        }
    }

    $csvLeaf = Split-Path -Leaf $CsvPath
    $catalogLeaf = Split-Path -Leaf $CatalogPath

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Rapport de conformité -- $repo")
    $lines.Add('')
    $lines.Add("Généré le $(Get-Date -Format 'yyyy-MM-dd') à partir de ``$csvLeaf`` et ``$catalogLeaf``.")
    $lines.Add('')
    $lines.Add("## Score global : $score % (pondéré par criticité)")
    $lines.Add('')
    $lines.Add("Calculé sur $applicableCount pratiques applicables du catalogue, qui en compte $totalCount : les pratiques marquées NA sont exclues du numérateur comme du dénominateur. Un score ne se compare donc qu'à assiette comparable.")
    $lines.Add('')
    $lines.Add('| Criticité | Poids | Respectées | Applicables |')
    $lines.Add('|---|---|---|---|')
    foreach ($b in $breakdown) {
        $lines.Add("| $($b.Criticality) $($b.Label) | $($b.Weight) | $($b.Ok) | $($b.Total) |")
    }
    $lines.Add('')

    $toFix = $rows | Where-Object { $_.Status -eq 'KO' } | Sort-Object -Property @{Expression = 'Weight'; Descending = $true }, Id
    if ($toFix) {
        $lines.Add('## À corriger en priorité')
        $lines.Add('')
        $lines.Add('| ID | Pratique | Criticité | Commentaire |')
        $lines.Add('|---|---|---|---|')
        foreach ($r in $toFix) {
            $lines.Add("| $($r.Id) | $($r.Practice) | $($r.Criticality) | $($r.Comment) |")
        }
        $lines.Add('')
    }

    $lines.Add('## Détail complet')
    $lines.Add('')
    foreach ($category in ($rows.Category | Select-Object -Unique)) {
        $lines.Add("### $category")
        $lines.Add('')
        $lines.Add('| ID | Pratique | Statut | Criticité | Commentaire |')
        $lines.Add('|---|---|---|---|---|')
        foreach ($r in ($rows | Where-Object { $_.Category -eq $category })) {
            $symbol = $(if ($StatusSymbol.ContainsKey($r.Status)) { $StatusSymbol[$r.Status] } else { "❓ $($r.Status)" })
            $lines.Add("| $($r.Id) | $($r.Practice) | $symbol | $($r.Criticality) | $($r.Comment) |")
        }
        $lines.Add('')
    }

    $notedRows = $rows | Where-Object { $_.Note }
    if ($notedRows) {
        $lines.Add('## Notes spécifiques à ce dépôt')
        $lines.Add('')
        foreach ($r in $notedRows) {
            $lines.Add("- **$($r.Id)** : $($r.Note)")
        }
        $lines.Add('')
    }

    return [pscustomobject]@{
        Repo       = $repo
        Score      = $score
        Applicable = $applicableCount
        Total      = $totalCount
        Breakdown  = $breakdown
        Content    = ($lines -join [Environment]::NewLine)
    }
}

function New-SummaryReport {
    param(
        [Parameter(Mandatory)]$RepoReports,
        [Parameter(Mandatory)][string]$OutputDir
    )

    $sorted = $RepoReports | Sort-Object -Property Score, Repo

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Rapport global -- bonnes pratiques GitHub')
    $lines.Add('')
    $lines.Add("Généré le $(Get-Date -Format 'yyyy-MM-dd') -- $($sorted.Count) dépôt(s), triés par score croissant (les pires en premier).")
    $lines.Add('')

    $avg = 0
    if ($sorted.Count -gt 0) {
        $avg = [Math]::Round(($sorted | Measure-Object -Property Score -Average).Average)
    }
    $lines.Add("Score moyen : $avg %")
    $lines.Add('')

    $lines.Add('| Dépôt | Score | Applicables | 🔴 Haute | 🟠 Moyenne | 🟡 Faible | ⚪ Optionnel | Rapport |')
    $lines.Add('|---|---|---|---|---|---|---|---|')
    foreach ($r in $sorted) {
        $cells = foreach ($emoji in @('🔴', '🟠', '🟡', '⚪')) {
            $b = $r.Breakdown | Where-Object { $_.Criticality -eq $emoji }
            if ($b) { "$($b.Ok)/$($b.Total)" } else { '—' }
        }
        $fileName = ($r.Repo -replace '/', '-') + '.md'
        $link = "[Détail]($([System.IO.Path]::GetFileName($OutputDir))/$fileName)"
        $lines.Add("| $($r.Repo) | $($r.Score) % | $($r.Applicable)/$($r.Total) | $($cells[0]) | $($cells[1]) | $($cells[2]) | $($cells[3]) | $link |")
    }
    $lines.Add('')

    return ($lines -join [Environment]::NewLine)
}

$catalogEntries = Read-Catalog -Path $CatalogPath

if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "Matrice de résultats introuvable : $CsvPath"
}
$auditRows = Import-Csv -LiteralPath $CsvPath -Encoding UTF8

if ($Repo) {
    $auditRows = $auditRows | Where-Object { $_.repo -in $Repo }
    if (-not $auditRows) {
        throw "Aucun dépôt correspondant dans $CsvPath pour : $($Repo -join ', ')"
    }
}

if (-not $Reports -and -not $Summary) {
    Write-Host "Aucune action demandée. Utilisez -Reports et/ou -Summary."
    return
}

$repoReports = foreach ($row in $auditRows) {
    New-RepoReport -CatalogEntries $catalogEntries -AuditRow $row
}

if ($Reports) {
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    foreach ($report in $repoReports) {
        $fileName = ($report.Repo -replace '/', '-') + '.md'
        $outPath = Join-Path $OutputDir $fileName
        Set-Content -LiteralPath $outPath -Value $report.Content -Encoding UTF8
        Write-Host "$($report.Repo) : $($report.Score)% -> $outPath"
    }
}

if ($Summary) {
    $summaryContent = New-SummaryReport -RepoReports $repoReports -OutputDir $OutputDir
    Set-Content -LiteralPath $SummaryPath -Value $summaryContent -Encoding UTF8
    Write-Host "Rapport global -> $SummaryPath"
}
