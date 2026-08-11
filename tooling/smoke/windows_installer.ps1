param(
  [Parameter(Mandatory = $true)][string]$InitialInstaller,
  [Parameter(Mandatory = $true)][string]$UpgradeInstaller,
  [Parameter(Mandatory = $true)][string]$UpdatePackage,
  [Parameter(Mandatory = $true)][string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
$initial = (Resolve-Path -LiteralPath $InitialInstaller).Path
$upgrade = (Resolve-Path -LiteralPath $UpgradeInstaller).Path
$update = (Resolve-Path -LiteralPath $UpdatePackage).Path
if (-not $update.EndsWith('.zip', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Update package must be a ZIP file.'
}
$root = [IO.Path]::GetFullPath($WorkRoot)
$token = [Guid]::NewGuid().ToString('N')
$install = Join-Path $root "install-$token"
$uninstallRoot = "$install-uninstall"
$rollback = "$install.rollback"
$staging = "$install.staging"
$data = Join-Path $root "data-$token"
$sentinel = Join-Path $data 'preserve.txt'
$payloadSentinel = Join-Path $install 'pre-zip-payload.txt'
$badFixtureRoot = Join-Path $root "bad-update-$token"
$badUpdate = Join-Path $root "bad-update-$token.zip"
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{225850DC-6179-46A0-962C-88F3BBA6D41D}_is1'
$programs = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
$shortcut = Join-Path $programs 'Maestro.lnk'
$relaunchPid = $null

function Get-ValidatedCleanupPath([string]$Path) {
  $target = [IO.Path]::GetFullPath($Path)
  $separator = [IO.Path]::DirectorySeparatorChar
  $rootPrefix = $root.TrimEnd($separator, [IO.Path]::AltDirectorySeparatorChar) + $separator
  if (-not $target.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Cleanup target is outside the smoke test root: $target"
  }
  return $target
}

function Invoke-Setup([string]$Path) {
  $process = Start-Process -FilePath $Path -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    ('/DIR="{0}"' -f $install)
  ) -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Installer failed with exit code $($process.ExitCode)."
  }
}

function Invoke-TestUninstaller {
  $validatedUninstallRoot = Get-ValidatedCleanupPath $uninstallRoot
  $uninstaller = Join-Path $validatedUninstallRoot 'unins000.exe'
  if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) { return }
  $process = Start-Process -FilePath $uninstaller -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'
  ) -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Uninstaller failed with exit code $($process.ExitCode)."
  }
}

function Invoke-ZipHelper([string]$Package) {
  $parent = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-NonInteractive', '-Command', 'Start-Sleep -Milliseconds 250'
  ) -PassThru
  $helper = Join-Path $install 'replace_windows_zip.ps1'
  $output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $helper `
    -PackagePath $Package `
    -InstallDirectory $install `
    -ParentProcessId $parent.Id `
    -RelaunchPath (Join-Path $install 'maestro.exe') 2>&1
  return [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output = @($output)
  }
}

if ((Test-Path -LiteralPath $uninstallKey) -or
    (Test-Path -LiteralPath $shortcut)) {
  throw 'Existing Maestro installation prevents installer smoke testing.'
}
if (Test-Path -LiteralPath $install) {
  throw "Smoke install directory already exists: $install"
}
if (Test-Path -LiteralPath $uninstallRoot) {
  throw "Smoke uninstaller directory already exists: $uninstallRoot"
}

try {
  New-Item -ItemType Directory -Path $root, $data -Force | Out-Null
  Set-Content -LiteralPath $sentinel -Value 'preserve-me'

  Invoke-Setup $initial
  foreach ($relative in @(
    'maestro.exe',
    'flutter_windows.dll',
    'flutter_secure_storage_windows_plugin.dll',
    'data',
    'replace_windows_zip.ps1'
  )) {
    if (-not (Test-Path -LiteralPath (Join-Path $install $relative))) {
      throw "Installed payload is missing: $relative"
    }
  }
  if (-not (Test-Path -LiteralPath $shortcut -PathType Leaf)) {
    throw 'Maestro Start Menu shortcut is missing.'
  }
  if (-not (Test-Path -LiteralPath $uninstallKey)) { throw 'Uninstall metadata is missing.' }
  if ((Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne '0.1.0') {
    throw 'Initial installer version metadata is incorrect.'
  }

  Invoke-Setup $upgrade
  if ((Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne '0.1.1') {
    throw 'Upgrade version metadata is incorrect.'
  }
  if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'preserve-me') {
    throw 'Application data changed during upgrade.'
  }

  Set-Content -LiteralPath $payloadSentinel -Value 'pre-zip-payload'
  New-Item -ItemType Directory -Path $badFixtureRoot -Force | Out-Null
  Expand-Archive -LiteralPath $update -DestinationPath $badFixtureRoot -Force
  $badRelaunch = Join-Path $badFixtureRoot 'maestro.exe'
  if (-not (Test-Path -LiteralPath $badRelaunch -PathType Leaf)) {
    throw 'Valid update fixture does not contain maestro.exe.'
  }
  Remove-Item -LiteralPath $badRelaunch -Force
  Compress-Archive -Path (Join-Path $badFixtureRoot '*') -DestinationPath $badUpdate -Force
  Remove-Item -LiteralPath (Get-ValidatedCleanupPath $badFixtureRoot) -Recurse -Force

  $badResult = Invoke-ZipHelper $badUpdate
  if ($badResult.ExitCode -eq 0) {
    throw 'Bad ZIP update unexpectedly succeeded.'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $install 'maestro.exe') -PathType Leaf) -or
      -not (Test-Path -LiteralPath $payloadSentinel -PathType Leaf)) {
    throw 'Prior installed payload was not restored after ZIP relaunch failure.'
  }
  if ((Test-Path -LiteralPath $rollback) -or (Test-Path -LiteralPath $staging)) {
    throw 'ZIP rollback or staging directory remains after restoration.'
  }
  if (-not (Test-Path -LiteralPath $uninstallKey) -or
      -not (Test-Path -LiteralPath $shortcut -PathType Leaf) -or
      -not (Test-Path -LiteralPath (Join-Path $uninstallRoot 'unins000.exe') -PathType Leaf)) {
    throw 'Installer registration changed during ZIP rollback.'
  }
  if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'preserve-me') {
    throw 'Application data changed during ZIP rollback.'
  }
  Write-Output 'windows-zip-update: rollback restored'

  $helperResult = Invoke-ZipHelper $update
  if ($helperResult.ExitCode -ne 0) {
    throw "ZIP update helper failed: $($helperResult.Output | Out-String)"
  }
  $helperOutput = $helperResult.Output
  $markers = @($helperOutput | Where-Object {
    "$_" -match '^windows-zip-update: relaunched [0-9]+$'
  })
  if ($markers.Count -ne 1) {
    throw "Expected one ZIP relaunch marker, found $($markers.Count): $($helperOutput | Out-String)"
  }
  $markerMatch = [regex]::Match("$($markers[0])", '^windows-zip-update: relaunched ([0-9]+)$')
  $relaunchPid = [int]$markerMatch.Groups[1].Value
  $relaunch = Get-Process -Id $relaunchPid -ErrorAction SilentlyContinue
  if ($null -ne $relaunch) {
    Stop-Process -Id $relaunchPid -Force
    Wait-Process -Id $relaunchPid -ErrorAction SilentlyContinue
  }
  Write-Output $markers[0]

  if (-not (Test-Path -LiteralPath (Join-Path $install 'zip-update-marker.txt') -PathType Leaf)) {
    throw 'ZIP update marker is missing.'
  }
  if (-not (Test-Path -LiteralPath $uninstallKey)) {
    throw 'Uninstall metadata was removed by ZIP replacement.'
  }
  if (-not (Test-Path -LiteralPath $shortcut -PathType Leaf)) {
    throw 'Start Menu shortcut was removed by ZIP replacement.'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $uninstallRoot 'unins000.exe') -PathType Leaf)) {
    throw 'External uninstaller was removed by ZIP replacement.'
  }

  Invoke-TestUninstaller
  if (Test-Path -LiteralPath $install) {
    throw 'Installer-owned install directory remains.'
  }
  if (Test-Path -LiteralPath $uninstallRoot) {
    throw 'Installer-owned uninstaller directory remains.'
  }
  if (Test-Path -LiteralPath $uninstallKey) {
    throw 'Uninstall metadata remains.'
  }
  if (Test-Path -LiteralPath $shortcut) {
    throw 'Start Menu shortcut remains.'
  }
  if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'preserve-me') {
    throw 'Uninstall removed application data.'
  }

  Write-Output 'windows-installer-smoke: passed'
}
finally {
  if ($null -ne $relaunchPid) {
    Stop-Process -Id $relaunchPid -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $relaunchPid -ErrorAction SilentlyContinue
  }
  Invoke-TestUninstaller
  foreach ($target in @(
    $install,
    $uninstallRoot,
    $rollback,
    $staging,
    $data,
    $badFixtureRoot,
    $badUpdate
  )) {
    if (Test-Path -LiteralPath $target) {
      Remove-Item -LiteralPath (Get-ValidatedCleanupPath $target) -Recurse -Force
    }
  }
}
