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

function Invoke-GhApiResponse {
    <#
        Comme Invoke-GhJson, mais conserve le code de statut HTTP.

        Indispensable pour la protection de branche : un dépôt public non
        protégé répond 404, un dépôt privé en plan gratuit répond 403 parce que
        la fonctionnalité y est indisponible. Les deux valent KO, mais la note
        doit distinguer la négligence de l'impossibilité.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Endpoint
    )

    $lines = @(& gh api -i $Endpoint 2>$null)

    $status = 0
    if ($lines.Count -gt 0 -and $lines[0] -match '^HTTP/[\d.]+\s+(?<code>\d{3})') {
        $status = [int]$Matches.code
    }

    $separator = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($lines[$i])) { $separator = $i; break }
    }

    $body = $null
    if ($separator -ge 0 -and $separator -lt ($lines.Count - 1)) {
        $payload = ($lines[($separator + 1)..($lines.Count - 1)] -join "`n")
        if (-not [string]::IsNullOrWhiteSpace($payload)) {
            try { $body = $payload | ConvertFrom-Json } catch { $body = $null }
        }
    }

    return [pscustomobject]@{
        Status = $status
        Body   = $body
    }
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

    $entries = @()
    if ($null -ne $result) {
        $entries = @($result | ForEach-Object {
            [pscustomobject]@{
                Name = $_.name
                Type = $_.type
            }
        })
    }

    # La virgule de tete empeche PowerShell de derouler un tableau vide en $null
    # au retour de la fonction. Sans elle, un repertoire absent se serialise en
    # null dans le cache, et @($null) vaut un tableau d'UN element au rechargement.
    return , $entries
}

function Get-RepoWorkflow {
    <#
        Telecharge le contenu de chaque workflow de .github/workflows.

        Un seul listing puis un appel par fichier : les depots du parc en ont
        entre zero et deux. La distinction « aucun workflow » / « des workflows
        sans le reglage attendu » compte, car elle separe un NA d'un KO.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo
    )

    # L'affectation intermediaire n'est pas cosmetique : Get-RepoDirectoryEntries
    # retourne « , $tableau » pour empecher le deroulement d'un tableau vide, et
    # consommer ce retour DIRECTEMENT dans un pipeline envoie tout le tableau
    # comme un seul element. Passer par une variable retablit le deroulement.
    $entries = Get-RepoDirectoryEntries -Repo $Repo -Path '.github/workflows'
    $files = @($entries | Where-Object { $_ -and $_.Type -eq 'file' -and $_.Name -match '\.ya?ml$' })

    $workflows = @()
    foreach ($file in $files) {
        $payload = Invoke-GhJson -Arguments @('api', "repos/$Repo/contents/.github/workflows/$($file.Name)")
        if (-not $payload -or -not $payload.content) { continue }

        # GitHub renvoie du base64 entrecoupe de sauts de ligne.
        $clean = ($payload.content -replace '\s', '')
        $text = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($clean))

        $workflows += [pscustomobject]@{
            Name    = $file.Name
            Content = $text
        }
    }

    return , $workflows
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
    $schemaVersion = 6

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

    $defaultBranch = 'main'
    if ($view.defaultBranchRef -and $view.defaultBranchRef.name) {
        $defaultBranch = $view.defaultBranchRef.name
    }

    $protectionResponse = Invoke-GhApiResponse -Endpoint "repos/$Repo/branches/$defaultBranch/protection"
    $protection = [pscustomobject]@{
        Branch = $defaultBranch
        Status = $protectionResponse.Status
        Data   = $protectionResponse.Body
    }

    # Les bots (dependabot, github-actions, Copilot) ne comptent pas comme
    # co-relecteurs humains : ils sont écartés ici plutôt que dans chaque
    # évaluateur.
    $collaborators = @()
    $collaboratorsRaw = Invoke-GhJson -Arguments @('api', "repos/$Repo/collaborators")
    if ($collaboratorsRaw) {
        $collaborators = @($collaboratorsRaw | ForEach-Object {
            [pscustomobject]@{
                Login = $_.login
                IsBot = ($_.type -eq 'Bot') -or ($_.login -match '\[bot\]$')
            }
        })
    }

    # security_and_analysis n'est pas expose par `gh repo view --json` : il faut
    # passer par l'API REST. Il vaut null sur un depot prive en plan gratuit, ou
    # le secret scanning n'est pas offert -- l'equivalent du 403 de la protection
    # de branche.
    $repoApi = Invoke-GhJson -Arguments @('api', "repos/$Repo")

    # 204 = alertes activees, 404 = desactivees. L'endpoint n'a pas de corps.
    $alertsResponse = Invoke-GhApiResponse -Endpoint "repos/$Repo/vulnerability-alerts"

    $automatedFixes = Invoke-GhJson -Arguments @('api', "repos/$Repo/automated-security-fixes")

    $security = [pscustomobject]@{
        Analysis                 = $repoApi.security_and_analysis
        VulnerabilityAlertStatus = $alertsResponse.Status
        AutomatedFixesEnabled    = [bool]($automatedFixes -and $automatedFixes.enabled)
    }

    $workflows = Get-RepoWorkflow -Repo $Repo

    # --paginate : nannyplus a plus de tags qu'une page n'en rend, et un tag hors
    # semver pourrait se cacher au-dela de la premiere.
    $tags = @()
    $tagsRaw = & gh api --paginate -q '.[].name' "repos/$Repo/tags" 2>$null
    if ($LASTEXITCODE -eq 0 -and $tagsRaw) {
        $tags = @($tagsRaw | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $workflowPermissions = Invoke-GhJson -Arguments @('api', "repos/$Repo/actions/permissions/workflow")

    $readme = ''
    $readmePayload = Invoke-GhJson -Arguments @('api', "repos/$Repo/readme")
    if ($readmePayload -and $readmePayload.content) {
        $clean = ($readmePayload.content -replace '\s', '')
        $readme = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($clean))
    }

    $snapshot = [pscustomobject]@{
        Repo          = $Repo
        SchemaVersion = $schemaVersion
        CollectedAt   = (Get-Date).ToString('s')
        View          = $view
        Contents      = $contents
        Protection    = $protection
        Collaborators = $collaborators
        Security      = $security
        Workflows     = $workflows
        Tags          = $tags
        Readme        = $readme
        WorkflowPermissions = $workflowPermissions
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
