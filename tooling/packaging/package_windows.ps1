param(
  [Parameter(Mandatory = $true)][string]$SemanticVersion,
  [Parameter(Mandatory = $true)][string]$CoreVersion,
  [Parameter(Mandatory = $true)][string]$WindowsVersion,
  [switch]$SkipBuild,
  [string]$InnoCompiler = $env:INNO_SETUP_COMPILER,
  # The in-application updater composes only when all four release defines are
  # stamped into the build. They are all-or-nothing: a partially configured
  # build would ship an updater that cannot verify what it downloads.
  [string]$UpdatePublicKeyBase64 = $env:MAESTRO_RELEASE_PUBLIC_KEY_BASE64,
  [string]$UpdateManifestUrl = $env:MAESTRO_RELEASE_MANIFEST_URL,
  [string]$UpdateSignatureUrl = $env:MAESTRO_RELEASE_SIGNATURE_URL,
  [string]$UpdatePackageType = 'zip'
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$distribution = Join-Path $repository 'dist'
$bundle = Join-Path $repository 'build\windows\x64\runner\Release'
$flutter = if ($env:FLUTTER_ROOT) {
  $windowsFlutter = Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
  if (Test-Path -LiteralPath $windowsFlutter -PathType Leaf) {
    $windowsFlutter
  } else {
    Join-Path $env:FLUTTER_ROOT 'bin/flutter'
  }
} else {
  (Get-Command flutter -ErrorAction Stop).Source
}
$dart = if ($env:FLUTTER_ROOT) {
  $windowsDart = Join-Path $env:FLUTTER_ROOT 'bin\cache\dart-sdk\bin\dart.exe'
  if (Test-Path -LiteralPath $windowsDart -PathType Leaf) {
    $windowsDart
  } else {
    Join-Path $env:FLUTTER_ROOT 'bin/cache/dart-sdk/bin/dart'
  }
} else {
  (Get-Command dart -ErrorAction Stop).Source
}
$projectionOutput = & $dart run (Join-Path $repository 'tooling\release\validate_release_projections.dart') $SemanticVersion --core $CoreVersion --windows $WindowsVersion 2>&1
if ($LASTEXITCODE -ne 0) { throw "Release projection validation failed: $($projectionOutput -join [Environment]::NewLine)" }
if ($env:MAESTRO_PACKAGING_PREFLIGHT_ONLY -eq '1') {
  $projectionOutput | Write-Output
  exit 0
}

$defines = @("--dart-define=MAESTRO_INSTALLED_VERSION=$SemanticVersion")
# The package type carries a platform default, so only the three published
# release inputs decide whether this build gets a runtime updater.
$updateInputs = @($UpdatePublicKeyBase64, $UpdateManifestUrl, $UpdateSignatureUrl)
$supplied = @($updateInputs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
if ($supplied -eq $updateInputs.Count) {
  if ([string]::IsNullOrWhiteSpace($UpdatePackageType)) { throw 'Runtime update package type must not be empty.' }
  $defines += "--dart-define=MAESTRO_RELEASE_PUBLIC_KEY_BASE64=$UpdatePublicKeyBase64"
  $defines += "--dart-define=MAESTRO_RELEASE_MANIFEST_URL=$UpdateManifestUrl"
  $defines += "--dart-define=MAESTRO_RELEASE_SIGNATURE_URL=$UpdateSignatureUrl"
  $defines += "--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=$UpdatePackageType"
  Write-Output 'runtime-updates: configured'
}
elseif ($supplied -ne 0) {
  throw 'Runtime update configuration is incomplete: supply the public key, manifest URL, and signature URL together, or none of them.'
}
else {
  Write-Output 'runtime-updates: unconfigured'
}

if (-not $SkipBuild) {
  & $flutter build windows --release --build-name $CoreVersion @defines
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

& $dart run msix:create --build-windows false --install-certificate false --output-path $distribution --output-name maestro-windows-x64 --version $WindowsVersion
if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed.' }
$msix = Get-ChildItem -LiteralPath $distribution -Filter 'maestro-windows-x64*.msix' | Select-Object -First 1
if ($null -eq $msix) { throw 'MSIX artifact was not produced.' }

$setup = & (Join-Path $repository 'tooling\packaging\windows\build_installer.ps1') `
  -DisplayVersion $SemanticVersion `
  -WindowsVersion $WindowsVersion `
  -Bundle $bundle `
  -OutputDirectory $distribution `
  -OutputName 'maestro-windows-x64-setup' `
  -CompilerPath $InnoCompiler
if ($LASTEXITCODE -ne 0) { throw 'Windows setup packaging failed.' }
$expectedSetup = Join-Path $distribution 'maestro-windows-x64-setup.exe'
if ($setup -ne [IO.Path]::GetFullPath($expectedSetup) -or -not (Test-Path -LiteralPath $expectedSetup -PathType Leaf)) {
  throw 'Windows setup executable was not produced.'
}

Write-Output "Created $zip"
Write-Output "Created $($msix.FullName)"
Write-Output "Created $setup"
