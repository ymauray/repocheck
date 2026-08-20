<#
    Applique les évaluateurs de pratiques à un ou plusieurs dépôts et met à jour
    la matrice de résultats.

    Seules les pratiques disposant d'un évaluateur sont écrites. Les autres
    colonnes sont laissées telles quelles : sur une matrice neuve elles restent
    vides, ce que le harnais de comparaison rapporte comme « non implémentée ».

    La colonne Notes n'est jamais réécrite. Les notes produites par les
    évaluateurs sont factuelles et vont à la console ; celles de la matrice sont
    de la prose écrite à la main, qu'un audit automatique n'a pas à écraser.
#>

function Invoke-RepoAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Repo,
        [Parameter(Mandatory)]$CatalogEntries,
        [Parameter(Mandatory)][string]$CsvPath,
        [Parameter(Mandatory)][hashtable]$Evaluators,
        [string]$CacheDir
    )

    $practiceIds = @($CatalogEntries | ForEach-Object { $_.Id })
    $columns = @('repo') + $practiceIds + @('Notes')

    $rows = [System.Collections.Generic.List[pscustomobject]]::new()
    if (Test-Path -LiteralPath $CsvPath) {
        foreach ($existing in @(Import-Csv -LiteralPath $CsvPath -Encoding UTF8)) {
            $rows.Add($existing)
        }
    }

    foreach ($target in $Repo) {
        $snapshot = Get-RepoSnapshot -Repo $target -CacheDir $CacheDir

        $row = $rows | Where-Object { $_.repo -eq $target } | Select-Object -First 1
        if (-not $row) {
            $ordered = [ordered]@{}
            foreach ($column in $columns) { $ordered[$column] = '' }
            $ordered['repo'] = $target
            $row = [pscustomobject]$ordered
            $rows.Add($row)
        }

        $notes = [System.Collections.Generic.List[string]]::new()
        $evaluated = 0

        foreach ($id in $practiceIds) {
            if (-not $Evaluators.ContainsKey($id)) { continue }

            $result = & $Evaluators[$id] $snapshot

            if ($null -eq $row.PSObject.Properties[$id]) {
                $row | Add-Member -NotePropertyName $id -NotePropertyValue '' -Force
            }
            $row.$id = $result.Status
            $evaluated++

            if ($result.Note) { $notes.Add($result.Note) }
        }

        Write-Host "$target : $evaluated pratique(s) évaluée(s)"
        foreach ($note in $notes) { Write-Host "    $note" }
    }

    $rows | Select-Object -Property $columns |
        Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8

    Write-Host "Matrice mise à jour -> $CsvPath"
}
