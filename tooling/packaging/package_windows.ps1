param(
  [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$distribution = Join-Path $repository 'dist'
$bundle = Join-Path $repository 'build\windows\x64\runner\Release'
$flutter = if ($env:FLUTTER_ROOT) {
  Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
} else {
  (Get-Command flutter -ErrorAction Stop).Source
}
$dart = if ($env:FLUTTER_ROOT) {
  Join-Path $env:FLUTTER_ROOT 'bin\cache\dart-sdk\bin\dart.exe'
} else {
  (Get-Command dart -ErrorAction Stop).Source
}

if (-not $SkipBuild) {
  & $flutter build windows --release --build-name $Version
  if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows release build failed.' }
}
if (-not (Test-Path -LiteralPath (Join-Path $bundle 'maestro.exe'))) {
  throw 'The Windows release bundle is incomplete.'
}
Copy-Item -LiteralPath (Join-Path $repository 'tooling\updates\replace_windows_zip.ps1') -Destination (Join-Path $bundle 'replace_windows_zip.ps1') -Force
New-Item -ItemType Directory -Path $distribution -Force | Out-Null
$zip = Join-Path $distribution 'maestro-windows-x64.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip

& $dart run msix:create --build-windows false --install-certificate false --output-path $distribution --output-name maestro-windows-x64 --version "$Version.0"
if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed.' }
$msix = Get-ChildItem -LiteralPath $distribution -Filter 'maestro-windows-x64*.msix' | Select-Object -First 1
if ($null -eq $msix) { throw 'MSIX artifact was not produced.' }

Write-Output "Created $zip"
Write-Output "Created $($msix.FullName)"
