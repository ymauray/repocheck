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

function Get-SecurityFeatureState {
    <#
        Lit l'etat d'une fonctionnalite de security_and_analysis.

        Retourne 'enabled', 'disabled', ou 'unavailable' quand l'objet entier est
        absent -- ce qui est le cas sur un depot prive en plan gratuit, ou le
        secret scanning n'est pas offert. C'est le pendant du 403 de la
        protection de branche : la fonctionnalite n'est pas negligee, elle est
        fermee.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Snapshot,
        [Parameter(Mandatory)][string]$Feature
    )

    $analysis = $Snapshot.Security.Analysis
    if (-not $analysis) { return 'unavailable' }

    $entry = $analysis.$Feature
    if (-not $entry -or -not $entry.status) { return 'unavailable' }

    return $entry.status
}

function Get-WorkflowActionReference {
    <#
        Extrait les references `uses:` d'un workflow, en ignorant les actions
        locales (./...) et les images docker, qui ne sont pas des actions du
        Marketplace et ne s'epinglent pas de la meme facon.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content
    )

    $references = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($match in [regex]::Matches($Content, '(?m)^\s*(?:-\s*)?uses:\s*([^\s#]+)')) {
        $reference = $match.Groups[1].Value.Trim("'", '"')
        if ($reference.StartsWith('.') -or $reference.StartsWith('docker://')) { continue }

        $owner = ($reference -split '/')[0]
        $ref = ''
        if ($reference -match '@(.+)$') { $ref = $Matches[1] }

        $references.Add([pscustomobject]@{
            Reference = $reference
            Owner     = $owner
            Ref       = $ref
            # Un SHA de commit fait 40 caracteres hexadecimaux ; tout le reste
            # est un tag ou une branche, donc deplacable.
            IsPinned  = ($ref -match '^[0-9a-f]{40}$')
        })
    }

    return , $references.ToArray()
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

        $selfUrl = "https://github.com/$($Snapshot.Repo)"

        # Une homepage renseignee et pointant ailleurs que sur le depot : un site
        # existe et il est lie.
        if ($homepage -and $homepage -ne $selfUrl) {
            return New-PracticeResult -Status 'OK'
        }

        # Sinon, la pratique ne se pose que si un site existe malgre tout.
        if ($Snapshot.HasPages) {
            $cause = 'champ homepage vide'
            if ($homepage) { $cause = "homepage auto-referente ($homepage)" }
            return New-PracticeResult -Status 'KO' `
                -Note "META-05: GitHub Pages actif mais $cause, le site n'est pas lie depuis le depot"
        }

        return New-PracticeResult -Status 'NA' `
            -Note 'META-05: N/A, aucun site ni documentation dedies a pointer'
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

        # Meme condition que BR-04 : sans reviewer dedie, un CODEOWNERS ne
        # declenche aucune demande de revue.
        $humans = @($Snapshot.Collaborators | Where-Object { $_ -and -not $_.IsBot })
        if ($humans.Count -le 1) {
            return New-PracticeResult -Status 'NA' `
                -Note 'GOV-06: N/A, mainteneur unique, aucun reviewer dedie a designer'
        }

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

    # SEC-01 -- Dependabot alerts. L'endpoint repond 204 si actives, 404 sinon.
    'SEC-01' = {
        param($Snapshot)

        if ($Snapshot.Security.VulnerabilityAlertStatus -eq 204) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' `
            -Note 'SEC-01: Dependabot alerts desactivees, aucune notification en cas de CVE sur une dependance'
    }

    # SEC-02 -- Dependabot security updates.
    'SEC-02' = {
        param($Snapshot)

        if ($Snapshot.Security.AutomatedFixesEnabled) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' `
            -Note 'SEC-02: Dependabot security updates desactivees'
    }

    # SEC-04 -- Secret scanning.
    'SEC-04' = {
        param($Snapshot)

        $state = Get-SecurityFeatureState -Snapshot $Snapshot -Feature 'secret_scanning'

        if ($state -eq 'enabled') {
            return New-PracticeResult -Status 'OK'
        }

        if ($state -eq 'unavailable') {
            return New-PracticeResult -Status 'KO' `
                -Note 'SEC-04: indisponible, secret scanning non offert sur depot prive en plan gratuit (security_and_analysis absent)'
        }

        return New-PracticeResult -Status 'KO' -Note 'SEC-04: secret scanning desactive'
    }

    # SEC-05 -- Push protection du secret scanning.
    'SEC-05' = {
        param($Snapshot)

        $state = Get-SecurityFeatureState -Snapshot $Snapshot -Feature 'secret_scanning_push_protection'

        if ($state -eq 'enabled') {
            return New-PracticeResult -Status 'OK'
        }

        if ($state -eq 'unavailable') {
            return New-PracticeResult -Status 'KO' `
                -Note 'SEC-05: indisponible, meme cause que SEC-04'
        }

        return New-PracticeResult -Status 'KO' -Note 'SEC-05: push protection desactivee'
    }

    # CI-03 -- Bloc permissions: explicite dans chaque workflow.
    # Le script verifie l'explicitation, pas la minimalite : juger qu'une
    # permission est plus large que necessaire suppose de savoir ce que fait le
    # workflow, ce qui n'est pas deductible du YAML.
    'CI-03' = {
        param($Snapshot)

        $workflows = @($Snapshot.Workflows | Where-Object { $_ })
        if ($workflows.Count -eq 0) {
            return New-PracticeResult -Status 'NA' -Note 'CI-03: N/A, aucun fichier de workflow a evaluer'
        }

        $without = @($workflows | Where-Object { $_.Content -notmatch '(?m)^\s*permissions:' })

        if ($without.Count -eq 0) {
            return New-PracticeResult -Status 'OK'
        }

        $names = @($without | ForEach-Object { $_.Name })
        return New-PracticeResult -Status 'KO' `
            -Note "CI-03: sans bloc permissions -- $($names -join ', ')"
    }

    # CI-04 -- Actions tierces epinglees a un SHA.
    # Ne vise que les actions hors org actions/ : voir le commentaire de la
    # pratique au catalogue pour le raisonnement.
    'CI-04' = {
        param($Snapshot)

        $workflows = @($Snapshot.Workflows | Where-Object { $_ })
        if ($workflows.Count -eq 0) {
            return New-PracticeResult -Status 'NA' -Note 'CI-04: N/A, aucun fichier de workflow a evaluer'
        }

        $thirdParty = [System.Collections.Generic.List[pscustomobject]]::new()
        foreach ($workflow in $workflows) {
            foreach ($reference in (Get-WorkflowActionReference -Content $workflow.Content)) {
                if ($reference.Owner -ne 'actions') { $thirdParty.Add($reference) }
            }
        }

        if ($thirdParty.Count -eq 0) {
            return New-PracticeResult -Status 'OK'
        }

        $loose = @($thirdParty | Where-Object { -not $_.IsPinned } | ForEach-Object { $_.Reference } | Select-Object -Unique)
        if ($loose.Count -eq 0) {
            return New-PracticeResult -Status 'OK'
        }

        return New-PracticeResult -Status 'KO' `
            -Note "CI-04: action(s) tierce(s) non epinglee(s) a un SHA -- $($loose -join ', ')"
    }

    # CI-06 -- Coherence des tags Git : uniquement vX.Y.Z.
    # Aucun tag n'est pas un echec, c'est une absence d'objet a evaluer.
    'CI-06' = {
        param($Snapshot)

        $tags = @($Snapshot.Tags | Where-Object { $_ })
        if ($tags.Count -eq 0) {
            return New-PracticeResult -Status 'NA' -Note 'CI-06: N/A, aucun tag a evaluer'
        }

        $offending = @($tags | Where-Object { $_ -notmatch '^v\d+\.\d+\.\d+$' })
        if ($offending.Count -eq 0) {
            return New-PracticeResult -Status 'OK'
        }

        $sample = @($offending | Select-Object -First 3)
        $note = "CI-06: $($offending.Count) tag(s) hors format vX.Y.Z sur $($tags.Count) -- $($sample -join ', ')"
        if ($offending.Count -gt $sample.Count) { $note = "$note..." }

        return New-PracticeResult -Status 'KO' -Note $note
    }

    # CI-07 -- Permissions par defaut des workflows en lecture seule.
    'CI-07' = {
        param($Snapshot)

        $permissions = $Snapshot.WorkflowPermissions
        if (-not $permissions -or -not $permissions.default_workflow_permissions) {
            return New-PracticeResult -Status 'KO' `
                -Note 'CI-07: permissions par defaut des workflows illisibles'
        }

        if ($permissions.default_workflow_permissions -eq 'read') {
            return New-PracticeResult -Status 'OK'
        }

        $note = "CI-07: default_workflow_permissions=$($permissions.default_workflow_permissions)"
        if ($permissions.can_approve_pull_request_reviews) {
            $note = "$note et can_approve_pull_request_reviews=true"
        }

        return New-PracticeResult -Status 'KO' -Note $note
    }

    # META-08 -- Badges de statut dans le README.
    # « Badge » n'est pas une notion formelle : on reconnait les fournisseurs
    # usuels plutot que toute image, car un README peut contenir une capture
    # d'ecran ou un logo sans pour autant afficher le moindre badge. Liste a
    # etendre si un nouveau fournisseur apparait.
    'META-08' = {
        param($Snapshot)

        # Sans README, le manquement est deja compte par META-04 : ne pas le
        # compter deux fois.
        if (-not $Snapshot.Readme) {
            return New-PracticeResult -Status 'NA' `
                -Note 'META-08: N/A, aucun README, le manquement releve de META-04'
        }

        $providers = @(
            'shields\.io',
            'badgen\.net',
            'forthebadge\.com',
            'badge\.svg',
            'github-readme-stats',
            'codecov\.io',
            'coveralls\.io'
        ) -join '|'

        $images = [regex]::Matches($Snapshot.Readme, '!\[[^\]]*\]\(([^)]+)\)')
        foreach ($image in $images) {
            if ($image.Groups[1].Value -match $providers) {
                return New-PracticeResult -Status 'OK'
            }
        }

        return New-PracticeResult -Status 'KO' -Note 'META-08: aucun badge de statut dans le README'
    }
}
