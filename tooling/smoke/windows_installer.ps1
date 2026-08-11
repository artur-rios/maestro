param(
  [Parameter(Mandatory = $true)][string]$InitialInstaller,
  [Parameter(Mandatory = $true)][string]$UpgradeInstaller,
  [Parameter(Mandatory = $true)][string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
$initial = (Resolve-Path -LiteralPath $InitialInstaller).Path
$upgrade = (Resolve-Path -LiteralPath $UpgradeInstaller).Path
$root = [IO.Path]::GetFullPath($WorkRoot)
$token = [Guid]::NewGuid().ToString('N')
$install = Join-Path $root "install-$token"
$data = Join-Path $root "data-$token"
$sentinel = Join-Path $data 'preserve.txt'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{225850DC-6179-46A0-962C-88F3BBA6D41D}_is1'
$programs = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
$shortcut = Join-Path $programs 'Maestro.lnk'

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
  $validatedInstall = Get-ValidatedCleanupPath $install
  $uninstaller = Join-Path $validatedInstall 'unins000.exe'
  if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) { return }
  $process = Start-Process -FilePath $uninstaller -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'
  ) -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Uninstaller failed with exit code $($process.ExitCode)."
  }
}

if ((Test-Path -LiteralPath $uninstallKey) -or
    (Test-Path -LiteralPath $shortcut)) {
  throw 'Existing Maestro installation prevents installer smoke testing.'
}
if (Test-Path -LiteralPath $install) {
  throw "Smoke install directory already exists: $install"
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

  Invoke-TestUninstaller
  if (Test-Path -LiteralPath $install) {
    throw 'Installer-owned install directory remains.'
  }
  if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'preserve-me') {
    throw 'Uninstall removed application data.'
  }

  Write-Output 'windows-installer-smoke: passed'
}
finally {
  Invoke-TestUninstaller
  foreach ($target in @($install, $data)) {
    if (Test-Path -LiteralPath $target) {
      Remove-Item -LiteralPath (Get-ValidatedCleanupPath $target) -Recurse -Force
    }
  }
}
