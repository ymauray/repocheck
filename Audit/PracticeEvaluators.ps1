<#
    Un évaluateur par pratique du catalogue, indexé par ID.

    Chaque évaluateur reçoit l'instantané du dépôt (voir Get-RepoSnapshot.ps1) et
    retourne un objet { Status; Note } où Status vaut OK, KO ou NA. La note est
    factuelle et destinée à la console : elle ne cherche pas à reproduire la prose
    des notes écrites à la main dans la référence.

    Une pratique absente de cette table n'est pas évaluée : -Audit laisse sa
    cellule inchangée, et le harnais de comparaison la rapporte comme
    « non implémentée » plutôt que comme un échec.
#>

function New-PracticeResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('OK', 'KO', 'NA')][string]$Status,
        [string]$Note
    )

    return [pscustomobject]@{
        Status = $Status
        Note   = $Note
    }
}

function Get-RepoFileMatch {
    <#
        Cherche un nom de fichier dans les emplacements donnés de l'instantané et
        retourne les chemins trouvés, sous la forme « Emplacement/nom ».
        La comparaison est insensible à la casse, comme la reconnaissance des
        fichiers communautaires par GitHub.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)][string]$Pattern,
        [string[]]$Location = @('Root', 'Github', 'Docs'),
        [ValidateSet('file', 'dir', 'any')][string]$Type = 'file'
    )

    $found = [System.Collections.Generic.List[string]]::new()

    foreach ($location in $Location) {
        foreach ($entry in @($Snapshot.Contents.$location)) {
            if (-not $entry) { continue }
            if ($Type -ne 'any' -and $entry.Type -ne $Type) { continue }
            if ($entry.Name -match $Pattern) {
                $found.Add("$location/$($entry.Name)")
            }
        }
    }

    return $found.ToArray()
}

function New-FilePresenceResult {
    <#
        Cas très courant : la pratique se résume à « ce fichier existe-t-il à un
        emplacement reconnu ».
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)][string]$Pattern,
        [string[]]$Location = @('Root', 'Github', 'Docs'),
        [Parameter(Mandatory)][string]$MissingNote
    )

    # Pas $matches : c'est une variable automatique alimentée par -match.
    $hits = Get-RepoFileMatch -Snapshot $Snapshot -Pattern $Pattern -Location $Location
    if ($hits.Count -gt 0) {
        return New-PracticeResult -Status 'OK'
    }

    return New-PracticeResult -Status 'KO' -Note $MissingNote
}

function Get-ProtectionUnavailableNote {
    <#
        Retourne une note si la protection de branche est indisponible plutot que
        simplement absente, sinon $null.

        Un depot public non protege repond 404 ; un depot prive en plan gratuit
        repond 403, parce que la fonctionnalite lui est fermee. La convention du
        catalogue est KO dans les deux cas -- publier le depot suffit a rendre la
        fonctionnalite disponible, l'ecart reste donc reel -- mais la note doit
        dire laquelle des deux situations on constate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)][string]$Id
    )

    if ($Snapshot.Protection.Status -eq 403) {
        return "${Id}: indisponible, protection de branche payante sur depot prive en plan gratuit (HTTP 403)"
    }

    return $null
}

$PracticeEvaluators = @{

    # META-01 -- Description du dépôt renseignée.
    # Le champ est soit rempli soit vide ; la justesse de son contenu n'est pas
    # évaluable par API et reste hors du périmètre du script.
    'META-01' = {
        param($Snapshot)

        $description = ''
        if ($Snapshot.View.description) {
            $description = ([string]$Snapshot.View.description).Trim()
        }

        if ($description) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' -Note 'META-01: description du depot vide'
    }

    # META-02 -- Topics renseignés.
    'META-02' = {
        param($Snapshot)

        $topics = @($Snapshot.View.repositoryTopics)
        $names = @($topics | Where-Object { $_ } | ForEach-Object { $_.name })

        if ($names.Count -gt 0) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' -Note 'META-02: aucun topic'
    }

    # META-03 -- LICENSE présente.
    # On se fie à la détection de GitHub plutôt qu'à la présence d'un fichier
    # nommé LICENSE : nannyplus publie sa GPL-3.0 via COPYING, et GitHub la
    # reconnaît correctement.
    'META-03' = {
        param($Snapshot)

        if ($Snapshot.View.licenseInfo -and $Snapshot.View.licenseInfo.key) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' -Note 'META-03: aucune licence detectee par GitHub'
    }

    # META-05 -- Homepage URL renseignée.
    # Une homepage qui pointe sur le dépôt lui-même n'oriente vers aucun site ni
    # documentation dédiés : elle ne vaut pas mieux qu'un champ vide.
    'META-05' = {
        param($Snapshot)

        $homepage = ''
        if ($Snapshot.View.homepageUrl) {
            $homepage = ([string]$Snapshot.View.homepageUrl).Trim().TrimEnd('/')
        }

        if (-not $homepage) {
            return New-PracticeResult -Status 'KO' -Note 'META-05: aucune homepage'
        }

        $selfUrl = "https://github.com/$($Snapshot.Repo)"
        if ($homepage -eq $selfUrl) {
            return New-PracticeResult -Status 'KO' `
                -Note "META-05: homepage auto-referente ($homepage), aucun site ni doc dedie"
        }

        return New-PracticeResult -Status 'OK'
    }

    # GOV-07 -- Discussions activées.
    'GOV-07' = {
        param($Snapshot)

        if ($Snapshot.View.hasDiscussionsEnabled) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' -Note 'GOV-07: Discussions non activees'
    }

    # BR-02 -- Suppression auto des branches mergées.
    'BR-02' = {
        param($Snapshot)

        if ($Snapshot.View.deleteBranchOnMerge) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' -Note 'BR-02: suppression auto des branches mergees desactivee'
    }

    # BR-03 -- Méthode de merge unique et cohérente.
    # La pratique ne prescrit pas laquelle : elle exige qu'il n'y en ait qu'une.
    'BR-03' = {
        param($Snapshot)

        $methods = [System.Collections.Generic.List[string]]::new()
        if ($Snapshot.View.mergeCommitAllowed) { $methods.Add('merge commit') }
        if ($Snapshot.View.squashMergeAllowed) { $methods.Add('squash') }
        if ($Snapshot.View.rebaseMergeAllowed) { $methods.Add('rebase') }

        if ($methods.Count -eq 1) {
            return New-PracticeResult -Status 'OK'
        }

        if ($methods.Count -eq 0) {
            return New-PracticeResult -Status 'KO' -Note 'BR-03: aucune methode de merge autorisee'
        }

        return New-PracticeResult -Status 'KO' `
            -Note "BR-03: $($methods.Count) methodes autorisees ($($methods -join ', ')), aucune convention"
    }

    # META-07 -- .editorconfig présent, à la racine uniquement.
    'META-07' = {
        param($Snapshot)
        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^\.editorconfig$' `
            -Location @('Root') -MissingNote 'META-07: pas de .editorconfig'
    }

    # GOV-01 a GOV-08 -- fichiers communautaires, reconnus par GitHub a la
    # racine, dans .github/ ou dans docs/.
    'GOV-01' = {
        param($Snapshot)
        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^CONTRIBUTING(\.(md|rst|txt))?$' `
            -MissingNote 'GOV-01: pas de CONTRIBUTING'
    }

    'GOV-02' = {
        param($Snapshot)
        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^CODE_OF_CONDUCT(\.(md|rst|txt))?$' `
            -MissingNote 'GOV-02: pas de CODE_OF_CONDUCT'
    }

    'GOV-03' = {
        param($Snapshot)
        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^SECURITY(\.(md|rst|txt))?$' `
            -MissingNote 'GOV-03: pas de SECURITY'
    }

    # GOV-04 -- template(s) d'issue : soit un dossier .github/ISSUE_TEMPLATE non
    # vide, soit le fichier unique historique.
    'GOV-04' = {
        param($Snapshot)

        # Le filtre n'est pas cosmetique : @($null) vaut un tableau d'un element.
        $templates = @($Snapshot.Contents.IssueTemplate | Where-Object { $_ })
        if ($templates.Count -gt 0) {
            return New-PracticeResult -Status 'OK'
        }

        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^ISSUE_TEMPLATE(\.(md|txt|yml|yaml))?$' `
            -MissingNote 'GOV-04: aucun template d''issue'
    }

    # GOV-05 -- template de pull request, fichier unique ou dossier de variantes.
    'GOV-05' = {
        param($Snapshot)

        $directory = Get-RepoFileMatch -Snapshot $Snapshot -Pattern '^PULL_REQUEST_TEMPLATE$' `
            -Location @('Root', 'Github', 'Docs') -Type 'dir'
        if ($directory.Count -gt 0) {
            return New-PracticeResult -Status 'OK'
        }

        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^PULL_REQUEST_TEMPLATE(\.(md|txt))?$' `
            -MissingNote 'GOV-05: pas de template de pull request'
    }

    'GOV-06' = {
        param($Snapshot)
        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^CODEOWNERS$' `
            -MissingNote 'GOV-06: pas de CODEOWNERS'
    }

    'GOV-08' = {
        param($Snapshot)
        return New-FilePresenceResult -Snapshot $Snapshot -Pattern '^SUPPORT(\.(md|rst|txt))?$' `
            -MissingNote 'GOV-08: pas de SUPPORT'
    }

    # TOOL-01 -- fichier d'instructions IA present ET au bon emplacement.
    # Un copilot-instructions.md ailleurs que dans .github/ est ignore
    # silencieusement par l'outil : sa presence vaut KO meme si un autre
    # assistant est correctement configure, sans quoi l'erreur passe inapercue.
    'TOOL-01' = {
        param($Snapshot)

        $misplaced = Get-RepoFileMatch -Snapshot $Snapshot -Pattern '^copilot-instructions\.md$' `
            -Location @('Root', 'Docs')

        $wellPlaced = @()
        $wellPlaced += Get-RepoFileMatch -Snapshot $Snapshot -Pattern '^(CLAUDE|GEMINI|AGENTS)\.md$' -Location @('Root')
        $wellPlaced += Get-RepoFileMatch -Snapshot $Snapshot -Pattern '^copilot-instructions\.md$' -Location @('Github')

        if ($misplaced.Count -gt 0) {
            return New-PracticeResult -Status 'KO' `
                -Note "TOOL-01: $($misplaced -join ', ') mal place, attendu dans .github/ -- ignore silencieusement par l'outil"
        }

        if ($wellPlaced.Count -gt 0) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' -Note 'TOOL-01: aucun fichier d''instructions IA'
    }

    # CI-02 -- Required status checks sur la branche protegee.
    'CI-02' = {
        param($Snapshot)

        $unavailable = Get-ProtectionUnavailableNote -Snapshot $Snapshot -Id 'CI-02'
        if ($unavailable) { return New-PracticeResult -Status 'KO' -Note $unavailable }

        if ($Snapshot.Protection.Status -ne 200) {
            return New-PracticeResult -Status 'KO' `
                -Note "CI-02: branche $($Snapshot.Protection.Branch) non protegee, donc aucun check requis"
        }

        $contexts = @()
        if ($Snapshot.Protection.Data.required_status_checks) {
            $contexts = @($Snapshot.Protection.Data.required_status_checks.contexts)
        }

        if ($contexts.Count -gt 0) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' `
            -Note 'CI-02: branche protegee mais aucun status check requis avant merge'
    }

    # BR-01 -- Branche par defaut protegee : force-push et suppression interdits.
    'BR-01' = {
        param($Snapshot)

        $unavailable = Get-ProtectionUnavailableNote -Snapshot $Snapshot -Id 'BR-01'
        if ($unavailable) { return New-PracticeResult -Status 'KO' -Note $unavailable }

        if ($Snapshot.Protection.Status -ne 200) {
            return New-PracticeResult -Status 'KO' `
                -Note "BR-01: aucune protection sur $($Snapshot.Protection.Branch)"
        }

        $forcePush = [bool]$Snapshot.Protection.Data.allow_force_pushes.enabled
        $deletions = [bool]$Snapshot.Protection.Data.allow_deletions.enabled

        if (-not $forcePush -and -not $deletions) {
            return New-PracticeResult -Status 'OK'
        }

        $permitted = [System.Collections.Generic.List[string]]::new()
        if ($forcePush) { $permitted.Add('force-push') }
        if ($deletions) { $permitted.Add('suppression') }

        return New-PracticeResult -Status 'KO' `
            -Note "BR-01: branche protegee mais $($permitted -join ' et ') encore autorise(s)"
    }

    # BR-04 -- Revues obligatoires avant merge.
    # Sans co-relecteur humain, la pratique est sans objet : c'est le seul
    # evaluateur qui produit un NA de lui-meme, et il le fait sur un critere
    # verifiable -- le nombre de collaborateurs humains du depot.
    'BR-04' = {
        param($Snapshot)

        $humans = @($Snapshot.Collaborators | Where-Object { $_ -and -not $_.IsBot })

        if ($humans.Count -le 1) {
            return New-PracticeResult -Status 'NA' `
                -Note 'BR-04: N/A, aucun co-relecteur humain (un seul collaborateur)'
        }

        $unavailable = Get-ProtectionUnavailableNote -Snapshot $Snapshot -Id 'BR-04'
        if ($unavailable) { return New-PracticeResult -Status 'KO' -Note $unavailable }

        if ($Snapshot.Protection.Status -ne 200) {
            return New-PracticeResult -Status 'KO' `
                -Note "BR-04: aucune protection sur $($Snapshot.Protection.Branch), donc aucune revue exigee"
        }

        $reviews = $Snapshot.Protection.Data.required_pull_request_reviews
        if ($reviews -and [int]$reviews.required_approving_review_count -ge 1) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' `
            -Note "BR-04: $($humans.Count) collaborateurs humains mais aucune revue exigee avant merge"
    }

    # BR-05 -- Protection appliquee aussi aux administrateurs.
    'BR-05' = {
        param($Snapshot)

        $unavailable = Get-ProtectionUnavailableNote -Snapshot $Snapshot -Id 'BR-05'
        if ($unavailable) { return New-PracticeResult -Status 'KO' -Note $unavailable }

        if ($Snapshot.Protection.Status -ne 200) {
            return New-PracticeResult -Status 'KO' `
                -Note "BR-05: aucune protection sur $($Snapshot.Protection.Branch)"
        }

        if ($Snapshot.Protection.Data.enforce_admins.enabled) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' `
            -Note 'BR-05: protection contournable par un administrateur (enforce_admins desactive)'
    }
}
