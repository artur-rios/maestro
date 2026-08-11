[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $PackagePath,
  [Parameter(Mandatory)] [string] $InstallDirectory,
  [Parameter(Mandatory)] [int] $ParentProcessId,
  [Parameter(Mandatory)] [string] $RelaunchPath
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackagePath).Path
$install = [IO.Path]::GetFullPath($InstallDirectory)
$relaunch = [IO.Path]::GetFullPath($RelaunchPath)
if (-not $package.EndsWith('.zip', [StringComparison]::OrdinalIgnoreCase)) { throw 'Update package must be a ZIP file.' }
if (-not (Test-Path -LiteralPath $install -PathType Container)) { throw 'Installation directory is unavailable.' }
if (-not $relaunch.StartsWith($install, [StringComparison]::OrdinalIgnoreCase)) { throw 'Relaunch path must remain inside installation directory.' }

while (Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 250 }
$parent = Split-Path -Parent $install
$leaf = Split-Path -Leaf $install
# Rollback keeps the last usable installation until relaunch succeeds.
$rollback = Join-Path $parent "$leaf.rollback"
$staging = Join-Path $parent "$leaf.staging"
foreach ($stalePath in @($staging, $rollback)) {
  if (Test-Path -LiteralPath $stalePath) {
    Remove-Item -LiteralPath $stalePath -Recurse -Force
  }
}
if ((Test-Path -LiteralPath $staging) -or (Test-Path -LiteralPath $rollback)) {
  throw 'Stale ZIP transaction paths could not be removed.'
}
$rollbackCreated = $false
New-Item -ItemType Directory -Path $staging | Out-Null
try {
  Expand-Archive -LiteralPath $package -DestinationPath $staging -Force
  Move-Item -LiteralPath $install -Destination $rollback
  $rollbackCreated = $true
  Move-Item -LiteralPath $staging -Destination $install
  $relaunchProcess = Start-Process -FilePath $relaunch -PassThru
  Write-Output "windows-zip-update: relaunched $($relaunchProcess.Id)"
  Remove-Item -LiteralPath $rollback -Recurse -Force -ErrorAction SilentlyContinue
} catch {
  if ($rollbackCreated) {
    if (Test-Path -LiteralPath $install) {
      Move-Item -LiteralPath $install -Destination $staging
    }
    Move-Item -LiteralPath $rollback -Destination $install
  }
  throw
} finally {
  Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}
