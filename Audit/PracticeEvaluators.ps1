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
}
