param(
  [Parameter(Mandatory = $true)][string]$SemanticVersion,
  [Parameter(Mandatory = $true)][string]$CoreVersion,
  [Parameter(Mandatory = $true)][string]$WindowsVersion,
  [switch]$SkipBuild,
  [string]$InnoCompiler = $env:INNO_SETUP_COMPILER,
  # The in-application updater composes only when all four release defines are
  # stamped into the build. The three published inputs are all-or-nothing: a
  # partially configured build would ship an updater that cannot verify what it
  # downloads. The package type is the fourth, and it is not an input: each
  # package carries its own (see Build-Bundle).
  [string]$UpdatePublicKeyBase64 = $env:MAESTRO_RELEASE_PUBLIC_KEY_BASE64,
  [string]$UpdateManifestUrl = $env:MAESTRO_RELEASE_MANIFEST_URL,
  [string]$UpdateSignatureUrl = $env:MAESTRO_RELEASE_SIGNATURE_URL
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
$updateInputs = @($UpdatePublicKeyBase64, $UpdateManifestUrl, $UpdateSignatureUrl)
$supplied = @($updateInputs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
$updatesConfigured = $false
if ($supplied -eq $updateInputs.Count) {
  $updatesConfigured = $true
  $defines += "--dart-define=MAESTRO_RELEASE_PUBLIC_KEY_BASE64=$UpdatePublicKeyBase64"
  $defines += "--dart-define=MAESTRO_RELEASE_MANIFEST_URL=$UpdateManifestUrl"
  $defines += "--dart-define=MAESTRO_RELEASE_SIGNATURE_URL=$UpdateSignatureUrl"
  Write-Output 'runtime-updates: configured'
}
elseif ($supplied -ne 0) {
  throw 'Runtime update configuration is incomplete: supply the public key, manifest URL, and signature URL together, or none of them.'
}
else {
  Write-Output 'runtime-updates: unconfigured'
}
if ($updatesConfigured -and $SkipBuild) {
  throw 'SkipBuild cannot package a build configured for updates: each package is built with its own update package type.'
}

# The package type tells the updater which release artifact to fetch and how to
# install it. The ZIP, and the setup.exe that installs the same files into a
# per-user folder, are updated by replace_windows_zip.ps1 swapping the install
# folder. An MSIX install lives in the read-only WindowsApps folder, which only
# Windows may change, so it is updated by handing the new .msix to
# Add-AppxPackage. The type is compiled in, so a build configured for updates is
# made once per package type. Without updates the bundles would be identical,
# and one build serves every package.
function Build-Bundle([string]$PackageType) {
  $packageDefine = @()
  if ($updatesConfigured) {
    $packageDefine = @("--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=$PackageType")
    Write-Output "runtime-update-package-type: $PackageType"
  }
  if (-not $SkipBuild) {
    & $flutter build windows --release --build-name $CoreVersion @defines @packageDefine
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows release build failed.' }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $bundle 'maestro.exe'))) {
    throw 'The Windows release bundle is incomplete.'
  }
}

Build-Bundle 'zip'
Copy-Item -LiteralPath (Join-Path $repository 'tooling\updates\replace_windows_zip.ps1') -Destination (Join-Path $bundle 'replace_windows_zip.ps1') -Force
New-Item -ItemType Directory -Path $distribution -Force | Out-Null
$zip = Join-Path $distribution 'maestro-windows-x64.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip

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

if ($updatesConfigured) {
  Build-Bundle 'msix'
  # A rebuild leaves files it did not produce in place. The ZIP helper cannot
  # update an MSIX install, so the MSIX does not ship it.
  $zipHelper = Join-Path $bundle 'replace_windows_zip.ps1'
  if (Test-Path -LiteralPath $zipHelper) { Remove-Item -LiteralPath $zipHelper -Force }
}
& $dart run msix:create --build-windows false --install-certificate false --output-path $distribution --output-name maestro-windows-x64 --version $WindowsVersion
if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed.' }
$msix = Get-ChildItem -LiteralPath $distribution -Filter 'maestro-windows-x64*.msix' | Select-Object -First 1
if ($null -eq $msix) { throw 'MSIX artifact was not produced.' }

Write-Output "Created $zip"
Write-Output "Created $($msix.FullName)"
Write-Output "Created $setup"
