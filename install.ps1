# Installs git-identity for the current user: adds this folder to the user
# PATH (so `git identity` works) and creates ~/.git-identities.json from the
# example if you don't have one yet. Safe to run again.

$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ";$dir"), 'User')
    Write-Host "Added $dir to your user PATH. Restart open terminals to pick it up."
} else {
    Write-Host "$dir is already on your user PATH."
}

$config = Join-Path $HOME '.git-identities.json'
if (-not (Test-Path $config)) {
    Copy-Item (Join-Path $dir 'git-identities.example.json') $config
    Write-Host "Created $config. Edit it to define your profiles."
} else {
    Write-Host "$config already exists; left it unchanged."
}
