param(
  [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [Parameter(Mandatory = $true)][string]$Bundle,
  [Parameter(Mandatory = $true)][string]$OutputDirectory,
  [string]$OutputName = 'maestro-windows-x64-setup',
  [string]$CompilerPath = $env:INNO_SETUP_COMPILER
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $Bundle).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
$compiler = if ($CompilerPath) { [IO.Path]::GetFullPath($CompilerPath) } else { $null }
$definition = Join-Path $PSScriptRoot 'maestro.iss'
$icon = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\windows\runner\resources\app_icon.ico')).Path

if (-not (Test-Path -LiteralPath (Join-Path $source 'maestro.exe') -PathType Leaf)) {
  throw 'The Windows release bundle is incomplete.'
}
if (-not $compiler -or -not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
  throw 'Inno Setup 6.7.1 compiler is unavailable.'
}
if ($OutputName -notmatch '^[A-Za-z0-9._-]+$') {
  throw 'Installer output name contains unsupported characters.'
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$compilerOutput = & $compiler "/DAppVersion=$Version" "/DSourceDir=$source" "/DOutputDir=$output" "/DOutputName=$OutputName" "/DAppIcon=$icon" $definition 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup compilation failed: $($compilerOutput -join [Environment]::NewLine)"
}
$installer = Join-Path $output "$OutputName.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf) -or (Get-Item -LiteralPath $installer).Length -le 0) {
  throw 'Windows setup executable was not produced.'
}
Write-Output ([IO.Path]::GetFullPath($installer))
