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
}
