<#
    Collecte, en une passe par dépôt, les données brutes dont les évaluateurs de
    pratiques ont besoin. Les pratiques ne rappellent jamais l'API : elles lisent
    cet instantané. Deux raisons : éviter de refaire les mêmes appels pour chaque
    pratique, et pouvoir rejouer une évaluation hors ligne depuis un cache.
#>

function Invoke-GhJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $raw = & gh @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return ($raw | ConvertFrom-Json)
}

function Get-RepoDirectoryEntries {
    <#
        Liste le contenu d'un répertoire du dépôt. Un répertoire absent renvoie
        une liste vide plutôt qu'une erreur : c'est le cas courant (beaucoup de
        dépôts n'ont ni .github/ ni docs/).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [string]$Path
    )

    $endpoint = "repos/$Repo/contents"
    if ($Path) { $endpoint = "$endpoint/$Path" }

    $result = Invoke-GhJson -Arguments @('api', $endpoint)
    if ($null -eq $result) { return @() }

    return @($result | ForEach-Object {
        [pscustomobject]@{
            Name = $_.name
            Type = $_.type
        }
    })
}

function Get-RepoSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,

        # Si fourni, l'instantané est lu depuis ce dossier s'il s'y trouve, et y
        # est écrit sinon. Rend les itérations de développement rejouables sans
        # réinterroger GitHub.
        [string]$CacheDir
    )

    # Incrémenter à chaque ajout de données collectées : un instantané mis en
    # cache avec un schéma plus ancien est ignoré plutôt que relu incomplet.
    $schemaVersion = 2

    $cacheFile = $null
    if ($CacheDir) {
        $cacheFile = Join-Path $CacheDir (($Repo -replace '/', '-') + '.json')
        if (Test-Path -LiteralPath $cacheFile) {
            $cached = Get-Content -LiteralPath $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cached.SchemaVersion -eq $schemaVersion) {
                Write-Verbose "Instantané lu depuis le cache : $cacheFile"
                return $cached
            }
            Write-Verbose "Cache obsolète (schéma $($cached.SchemaVersion)), recollecte : $Repo"
        }
    }

    # Un seul appel couvre déjà les métadonnées, la gouvernance des merges et la
    # visibilité : il n'y a rien à gagner à le découper.
    $viewFields = @(
        'name', 'description', 'homepageUrl', 'repositoryTopics', 'licenseInfo',
        'isPrivate', 'visibility', 'defaultBranchRef', 'hasDiscussionsEnabled',
        'deleteBranchOnMerge', 'mergeCommitAllowed', 'squashMergeAllowed',
        'rebaseMergeAllowed', 'primaryLanguage', 'createdAt', 'pushedAt'
    ) -join ','

    $view = Invoke-GhJson -Arguments @('repo', 'view', $Repo, '--json', $viewFields)
    if ($null -eq $view) {
        throw "Impossible de lire le dépôt via gh : $Repo"
    }

    # Les emplacements canoniques des fichiers communautaires et d'instructions :
    # GitHub reconnaît la racine, .github/ et docs/. Quatre listings bornés
    # plutôt qu'un arbre récursif, qui serait tronqué sur un gros dépôt.
    $contents = [pscustomobject]@{
        Root          = Get-RepoDirectoryEntries -Repo $Repo
        Github        = Get-RepoDirectoryEntries -Repo $Repo -Path '.github'
        IssueTemplate = Get-RepoDirectoryEntries -Repo $Repo -Path '.github/ISSUE_TEMPLATE'
        Docs          = Get-RepoDirectoryEntries -Repo $Repo -Path 'docs'
    }

    $snapshot = [pscustomobject]@{
        Repo          = $Repo
        SchemaVersion = $schemaVersion
        CollectedAt   = (Get-Date).ToString('s')
        View          = $view
        Contents      = $contents
    }

    if ($cacheFile) {
        if (-not (Test-Path -LiteralPath $CacheDir)) {
            New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
        }
        $snapshot | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $cacheFile -Encoding UTF8
        Write-Verbose "Instantané mis en cache : $cacheFile"
    }

    return $snapshot
}
