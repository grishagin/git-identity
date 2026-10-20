<#
git-identity: switch the git identity (name, email, SSH key, signing key)
of the current repo between profiles in ~/.git-identities.json.

  git identity                 show the current repo's identity
  git identity list            list profiles (* = active here)
  git identity <profile>       apply a profile to the current repo
  git identity <profile> -g    apply a profile globally (~/.gitconfig)
  git identity edit            open the profiles file

Profile fields: name, email (required); sshKey, signingKey (optional).
sshKey sets core.sshCommand so pushes authenticate with that key even when
the remote uses plain github.com. signingKey: a .pub path enables SSH
commit signing, anything else is treated as a GPG key id.
#>

$ErrorActionPreference = 'Stop'
$ConfigPath = Join-Path $HOME '.git-identities.json'

function Fail($msg) { Write-Host "git-identity: $msg" -ForegroundColor Red; exit 1 }

function Expand-Home($path) {
    if ($path -match '^~[\\/]') { $path = Join-Path $HOME $path.Substring(2) }
    $path -replace '\\', '/'   # ssh and git both prefer forward slashes
}

function Get-Profiles {
    if (-not (Test-Path $ConfigPath)) { Fail "no profiles file at $ConfigPath" }
    $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $profiles = [ordered]@{}
    foreach ($p in $json.profiles.PSObject.Properties) { $profiles[$p.Name] = $p.Value }
    if ($profiles.Count -eq 0) { Fail "no profiles defined in $ConfigPath" }
    $profiles
}

function Get-GitValue($key, $scope) {
    $args_ = @('config')
    if ($scope) { $args_ += "--$scope" }
    $value = & git @args_ --get $key 2>$null
    if ($LASTEXITCODE -eq 0) { $value } else { $null }
}

function Set-GitValue($scope, $key, $value) {
    if ($null -ne $value -and $value -ne '') {
        & git config "--$scope" $key $value
    } else {
        # Clear leftovers from a previous profile; exit code 5 = key wasn't set
        & git config "--$scope" --unset-all $key 2>$null
    }
}

function Test-InRepo { & git rev-parse --is-inside-work-tree 2>$null | Out-Null; $LASTEXITCODE -eq 0 }

function Show-Current {
    $profiles = Get-Profiles
    $email = Get-GitValue 'user.email'
    $name = Get-GitValue 'user.name'
    $scope = (& git config --show-scope --get user.email 2>$null) -split '\s+' | Select-Object -First 1
    $match = $profiles.Keys | Where-Object { $profiles[$_].email -eq $email } | Select-Object -First 1

    if (-not $email) { Write-Host 'No identity set.' -ForegroundColor Yellow; return }
    $label = if ($match) { $match } else { '(no matching profile)' }
    Write-Host "$label" -ForegroundColor Cyan -NoNewline
    Write-Host "  $name <$email>  [$scope]"
    $ssh = Get-GitValue 'core.sshCommand'
    if ($ssh) { Write-Host "  ssh: $ssh" -ForegroundColor DarkGray }
    if ((Test-InRepo) -and $scope -ne 'local') {
        Write-Host '  This repo has no identity of its own; it inherits the one above.' -ForegroundColor Yellow
    }
}

function Show-List {
    $profiles = Get-Profiles
    $email = Get-GitValue 'user.email'
    foreach ($key in $profiles.Keys) {
        $p = $profiles[$key]
        $mark = if ($p.email -eq $email) { '*' } else { ' ' }
        Write-Host ("{0} {1,-12} {2} <{3}>" -f $mark, $key, $p.name, $p.email)
    }
}

function Use-Profile($key, $global) {
    $profiles = Get-Profiles
    if (-not $profiles.Contains($key)) {
        Fail "unknown profile '$key'. Known: $($profiles.Keys -join ', ')"
    }
    $p = $profiles[$key]
    if (-not $p.name -or -not $p.email) { Fail "profile '$key' needs both name and email" }

    $scope = if ($global) { 'global' } else { 'local' }
    if (-not $global -and -not (Test-InRepo)) { Fail 'not inside a git repository (use -g for global)' }

    Set-GitValue $scope 'user.name' $p.name
    Set-GitValue $scope 'user.email' $p.email

    $sshCommand = $null
    if ($p.sshKey) {
        $keyPath = Expand-Home $p.sshKey
        if (-not (Test-Path $keyPath)) { Fail "ssh key not found: $keyPath" }
        $sshCommand = "ssh -i `"$keyPath`" -o IdentitiesOnly=yes"
    }
    Set-GitValue $scope 'core.sshCommand' $sshCommand

    if ($p.signingKey) {
        $isSsh = $p.signingKey -like '*.pub'
        $signingKey = if ($isSsh) { Expand-Home $p.signingKey } else { $p.signingKey }
        Set-GitValue $scope 'user.signingkey' $signingKey
        Set-GitValue $scope 'gpg.format' $(if ($isSsh) { 'ssh' } else { $null })
        Set-GitValue $scope 'commit.gpgsign' 'true'
    } else {
        Set-GitValue $scope 'user.signingkey' $null
        Set-GitValue $scope 'gpg.format' $null
        Set-GitValue $scope 'commit.gpgsign' $null
    }

    Write-Host "Switched $scope identity to " -NoNewline
    Write-Host $key -ForegroundColor Cyan -NoNewline
    Write-Host " ($($p.name) <$($p.email)>)"
}

$rest = @($args | Where-Object { $_ -notin '-g', '--global' })
$global = $args.Count -ne $rest.Count

switch ($rest[0]) {
    $null { Show-Current }
    { $_ -in 'list', 'ls' } { Show-List }
    'edit' { Start-Process $ConfigPath }
    { $_ -in 'help', '-h', '--help' } { Get-Content $PSCommandPath -TotalCount 15 | Select-Object -Skip 1 }
    default { Use-Profile $rest[0] $global }
}
