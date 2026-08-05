param(
  [Parameter(Mandatory = $true)][string]$InitialPackage,
  [Parameter(Mandatory = $true)][string]$UpdatePackage,
  [Parameter(Mandatory = $true)][string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
$initial = (Resolve-Path -LiteralPath $InitialPackage).Path
$update = (Resolve-Path -LiteralPath $UpdatePackage).Path
$root = [System.IO.Path]::GetFullPath($WorkRoot)
$token = [Guid]::NewGuid().ToString('N')
$install = Join-Path $root "install-$token"
$staged = Join-Path $root "update-$token"
$data = Join-Path $root "data-$token"

New-Item -ItemType Directory -Path $install, $staged, $data -Force | Out-Null
Set-Content -LiteralPath (Join-Path $data 'preserve.txt') -Value 'preserve-me'
Expand-Archive -LiteralPath $initial -DestinationPath $install
Expand-Archive -LiteralPath $update -DestinationPath $staged

if (-not (Test-Path -LiteralPath (Join-Path $install 'maestro.exe'))) {
  throw 'Initial portable package does not contain maestro.exe.'
}
if (-not (Test-Path -LiteralPath (Join-Path $staged 'maestro.exe'))) {
  throw 'Update portable package does not contain maestro.exe.'
}
if ((Get-Content -Raw -LiteralPath (Join-Path $data 'preserve.txt')).Trim() -ne 'preserve-me') {
  throw 'Application data changed during package staging.'
}
Write-Output 'windows-install-update-smoke: passed'
