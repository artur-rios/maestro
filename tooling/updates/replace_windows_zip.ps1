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
Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $rollback -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $staging | Out-Null
try {
  Expand-Archive -LiteralPath $package -DestinationPath $staging -Force
  Move-Item -LiteralPath $install -Destination $rollback
  Move-Item -LiteralPath $staging -Destination $install
  $relaunchProcess = Start-Process -FilePath $relaunch -PassThru
  Write-Output "windows-zip-update: relaunched $($relaunchProcess.Id)"
  Remove-Item -LiteralPath $rollback -Recurse -Force -ErrorAction SilentlyContinue
} catch {
  if (-not (Test-Path -LiteralPath $install) -and (Test-Path -LiteralPath $rollback)) { Move-Item -LiteralPath $rollback -Destination $install }
  throw
} finally {
  Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}
