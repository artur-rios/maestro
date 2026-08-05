param(
  [Parameter(Mandatory = $true)][string]$PackagePath,
  [Parameter(Mandatory = $true)][string]$InstallDirectory,
  [Parameter(Mandatory = $true)][int]$ParentProcessId
)

$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackagePath).Path
$install = [System.IO.Path]::GetFullPath($InstallDirectory)
$root = [System.IO.Path]::GetPathRoot($install)
if ($install -eq $root) {
  throw 'Refusing to replace a filesystem root.'
}

Wait-Process -Id $ParentProcessId -ErrorAction SilentlyContinue
$parent = Split-Path -Parent $install
$name = Split-Path -Leaf $install
$token = [Guid]::NewGuid().ToString('N')
$staging = Join-Path $parent "$name.update-$token"
$backup = Join-Path $parent "$name.backup-$token"

try {
  Expand-Archive -LiteralPath $package -DestinationPath $staging
  if (-not (Test-Path -LiteralPath (Join-Path $staging 'maestro.exe'))) {
    throw 'The staged ZIP does not contain maestro.exe.'
  }
  Move-Item -LiteralPath $install -Destination $backup
  try {
    Move-Item -LiteralPath $staging -Destination $install
  }
  catch {
    Move-Item -LiteralPath $backup -Destination $install
    throw
  }
  Remove-Item -LiteralPath $backup -Recurse -Force
}
finally {
  if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
  }
}
