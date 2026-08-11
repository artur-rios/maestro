param(
  [Parameter(Mandatory = $true)][string]$ProductionInstaller,
  [Parameter(Mandatory = $true)][string]$InitialInstaller,
  [Parameter(Mandatory = $true)][string]$UpgradeInstaller,
  [Parameter(Mandatory = $true)][string]$UpdatePackage,
  [Parameter(Mandatory = $true)][string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
$production = (Resolve-Path -LiteralPath $ProductionInstaller).Path
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
$data = Join-Path $root "data-$token"
$sentinel = Join-Path $data 'preserve.txt'
$payloadSentinel = Join-Path $install 'pre-zip-payload.txt'
$corruptUpdate = Join-Path $root "corrupt-update-$token.zip"
$badFixtureRoot = Join-Path $root "bad-update-$token"
$badUpdate = Join-Path $root "bad-update-$token.zip"
$productionOverride = Join-Path $root "production-override-$token"
$concurrentOutput = Join-Path $root "concurrent-$token.out"
$concurrentError = Join-Path $root "concurrent-$token.err"
$gateRelease = Join-Path $root "concurrent-$token.release"
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{225850DC-6179-46A0-962C-88F3BBA6D41D}_is1'
$programs = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Programs)
$shortcut = Join-Path $programs 'Maestro.lnk'
$productionInstall = Join-Path $env:LOCALAPPDATA 'Programs\Maestro'
$productionUninstallRoot = "$productionInstall-uninstall"
$productionSentinel = Join-Path $productionInstall "unowned-$token.txt"
$relaunchPid = $null
$gateParent = $null
$concurrentHelper = $null

function Get-ValidatedCleanupPath([string]$Path) {
  $target = [IO.Path]::GetFullPath($Path)
  $separator = [IO.Path]::DirectorySeparatorChar
  $rootPrefix = $root.TrimEnd($separator, [IO.Path]::AltDirectorySeparatorChar) + $separator
  if (-not $target.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Cleanup target is outside the smoke test root: $target"
  }
  return $target
}

function Invoke-SetupProcess([string]$Path, [string]$Target) {
  return Start-Process -FilePath $Path -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    ('/DIR="{0}"' -f $Target)
  ) -Wait -PassThru
}

function Invoke-Setup([string]$Path) {
  $process = Invoke-SetupProcess $Path $install
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

function Get-ZipTransactionPaths {
  $parent = Split-Path -Parent $install
  $leaf = Split-Path -Leaf $install
  return @(
    Get-ChildItem -LiteralPath $parent -Filter "$leaf.rollback.*" -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $parent -Filter "$leaf.staging.*" -ErrorAction SilentlyContinue
  )
}

function Assert-NoZipTransactionPaths([string]$Context) {
  $transactionPaths = @(Get-ZipTransactionPaths)
  if ($transactionPaths.Count -ne 0) {
    throw "ZIP transaction paths remain after ${Context}: $($transactionPaths.FullName -join ', ')"
  }
}

function Assert-PreservedLifecycle([string]$Context) {
  if (-not (Test-Path -LiteralPath (Join-Path $install 'maestro.exe') -PathType Leaf) -or
      -not (Test-Path -LiteralPath $payloadSentinel -PathType Leaf)) {
    throw "Installed payload changed after $Context."
  }
  Assert-NoZipTransactionPaths $Context
  if (-not (Test-Path -LiteralPath $uninstallKey) -or
      -not (Test-Path -LiteralPath $shortcut -PathType Leaf) -or
      -not (Test-Path -LiteralPath (Join-Path $uninstallRoot 'unins000.exe') -PathType Leaf)) {
    throw "Installer registration changed during $Context."
  }
  if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'preserve-me') {
    throw "Application data changed during $Context."
  }
}

if ((Test-Path -LiteralPath $uninstallKey) -or
    (Test-Path -LiteralPath $shortcut) -or
    (Test-Path -LiteralPath $productionInstall) -or
    (Test-Path -LiteralPath $productionUninstallRoot)) {
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

  $overrideProcess = Invoke-SetupProcess $production $productionOverride
  if ($overrideProcess.ExitCode -eq 0) {
    throw 'Production installer unexpectedly accepted a custom directory.'
  }
  if ((Test-Path -LiteralPath $productionOverride) -or
      (Test-Path -LiteralPath $uninstallKey) -or
      (Test-Path -LiteralPath $shortcut)) {
    throw 'Production installer mutated state before rejecting a custom directory.'
  }
  Write-Output 'windows-installer-ownership: custom directory rejected'

  New-Item -ItemType Directory -Path $productionInstall | Out-Null
  Set-Content -LiteralPath $productionSentinel -Value "unowned-$token"
  $unownedProcess = Invoke-SetupProcess $production $productionInstall
  if ($unownedProcess.ExitCode -eq 0) {
    throw 'Production installer unexpectedly claimed an unowned directory.'
  }
  if ((Get-Content -Raw -LiteralPath $productionSentinel).Trim() -ne "unowned-$token" -or
      (Test-Path -LiteralPath (Join-Path $productionInstall 'maestro.exe')) -or
      (Test-Path -LiteralPath $productionUninstallRoot) -or
      (Test-Path -LiteralPath $uninstallKey) -or
      (Test-Path -LiteralPath $shortcut)) {
    throw 'Production installer mutated an unowned directory before rejection.'
  }
  Remove-Item -LiteralPath $productionSentinel -Force
  Remove-Item -LiteralPath $productionInstall -Force
  Write-Output 'windows-installer-ownership: unowned directory rejected'

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
  [IO.File]::WriteAllBytes($corruptUpdate, [byte[]](0x4e, 0x4f, 0x54, 0x5a, 0x49, 0x50))

  $gateParent = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-NonInteractive', '-Command',
    ('while (-not (Test-Path -LiteralPath ''{0}'')) {{ Start-Sleep -Milliseconds 100 }}' -f $gateRelease)
  ) -PassThru
  $helper = Join-Path $install 'replace_windows_zip.ps1'
  $relaunchPath = Join-Path $install 'maestro.exe'
  $concurrentHelper = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File',
    ('"{0}"' -f $helper), '-PackagePath', ('"{0}"' -f $corruptUpdate),
    '-InstallDirectory', ('"{0}"' -f $install), '-ParentProcessId', $gateParent.Id,
    '-RelaunchPath', ('"{0}"' -f $relaunchPath)
  ) -RedirectStandardOutput $concurrentOutput -RedirectStandardError $concurrentError -PassThru

  $lockDeadline = [DateTime]::UtcNow.AddSeconds(15)
  while ($true) {
    $observedLockOutput = if (Test-Path -LiteralPath $concurrentOutput) {
      [string](Get-Content -Raw -LiteralPath $concurrentOutput -ErrorAction SilentlyContinue)
    }
    else {
      ''
    }
    if ($observedLockOutput -match 'windows-zip-update: lock acquired') { break }
    if ($concurrentHelper.HasExited) {
      throw "First concurrent helper exited before acquiring its lock: $(Get-Content -Raw -LiteralPath $concurrentError -ErrorAction SilentlyContinue)"
    }
    if ([DateTime]::UtcNow -ge $lockDeadline) {
      throw 'First concurrent helper did not report lock acquisition.'
    }
    Start-Sleep -Milliseconds 100
    $concurrentHelper.Refresh()
  }
  $gateParent.Refresh()
  $concurrentHelper.Refresh()
  if ($gateParent.HasExited -or $concurrentHelper.HasExited) {
    throw 'First concurrent helper was not held behind its test-owned parent.'
  }

  $busyResult = Invoke-ZipHelper $corruptUpdate
  if ($busyResult.ExitCode -eq 0 -or
      (($busyResult.Output | Out-String) -notmatch 'windows-zip-update: busy')) {
    $firstOutput = Get-Content -Raw -LiteralPath $concurrentOutput -ErrorAction SilentlyContinue
    throw "Second concurrent helper did not fail closed. First: $firstOutput Second: $($busyResult.Output | Out-String)"
  }
  Assert-PreservedLifecycle 'concurrent helper rejection'
  Write-Output 'windows-zip-update: concurrent rejected'

  Set-Content -LiteralPath $gateRelease -Value 'release'
  Wait-Process -Id $gateParent.Id -ErrorAction SilentlyContinue
  $gateParent = $null
  Wait-Process -Id $concurrentHelper.Id
  $concurrentHelper.Refresh()
  if ($concurrentHelper.ExitCode -eq 0) {
    throw 'Corrupt ZIP update unexpectedly succeeded.'
  }
  $concurrentHelper = $null
  Assert-PreservedLifecycle 'pre-swap ZIP failure'
  Write-Output 'windows-zip-update: pre-swap preserved'

  New-Item -ItemType Directory -Path $badFixtureRoot -Force | Out-Null
  Expand-Archive -LiteralPath $update -DestinationPath $badFixtureRoot -Force
  $badRelaunch = Join-Path $badFixtureRoot 'maestro.exe'
  if (-not (Test-Path -LiteralPath $badRelaunch -PathType Leaf)) {
    throw 'Valid update fixture does not contain maestro.exe.'
  }
  Remove-Item -LiteralPath $badRelaunch -Force
  $earlyExitExecutable = Join-Path $env:SystemRoot 'System32\where.exe'
  if (-not (Test-Path -LiteralPath $earlyExitExecutable -PathType Leaf)) {
    throw 'The no-readiness fixture executable is unavailable.'
  }
  Copy-Item -LiteralPath $earlyExitExecutable -Destination $badRelaunch
  Compress-Archive -Path (Join-Path $badFixtureRoot '*') -DestinationPath $badUpdate -Force
  Remove-Item -LiteralPath (Get-ValidatedCleanupPath $badFixtureRoot) -Recurse -Force

  $badResult = Invoke-ZipHelper $badUpdate
  if ($badResult.ExitCode -eq 0 -or
      (($badResult.Output | Out-String) -notmatch 'relaunched process exited early')) {
    throw "No-readiness ZIP update did not fail after process creation: $($badResult.Output | Out-String)"
  }
  if (($badResult.Output | Out-String) -notmatch 'windows-zip-update: relaunched') {
    throw 'No-readiness fixture failed before process creation.'
  }
  Assert-PreservedLifecycle 'ZIP readiness rollback'
  Write-Output 'windows-zip-update: rollback restored'

  $helperResult = Invoke-ZipHelper $update
  if ($helperResult.ExitCode -ne 0) {
    throw "ZIP update helper failed: $($helperResult.Output | Out-String)"
  }
  $helperOutput = $helperResult.Output
  $relaunchMarkers = @($helperOutput | Where-Object {
    "$_" -match '^windows-zip-update: relaunched [0-9]+$'
  })
  $readyMarkers = @($helperOutput | Where-Object {
    "$_" -match '^windows-zip-update: ready [0-9]+$'
  })
  if ($relaunchMarkers.Count -ne 1 -or $readyMarkers.Count -ne 1) {
    throw "Expected one relaunch and readiness marker: $($helperOutput | Out-String)"
  }
  $relaunchMatch = [regex]::Match("$($relaunchMarkers[0])", '^windows-zip-update: relaunched ([0-9]+)$')
  $readyMatch = [regex]::Match("$($readyMarkers[0])", '^windows-zip-update: ready ([0-9]+)$')
  if ($relaunchMatch.Groups[1].Value -ne $readyMatch.Groups[1].Value) {
    throw 'ZIP readiness came from a process other than the relaunched Maestro.'
  }
  $relaunchPid = [int]$relaunchMatch.Groups[1].Value
  $relaunch = Get-Process -Id $relaunchPid -ErrorAction SilentlyContinue
  if ($null -ne $relaunch) {
    Stop-Process -Id $relaunchPid -Force
    Wait-Process -Id $relaunchPid -ErrorAction SilentlyContinue
  }
  Write-Output $relaunchMarkers[0]
  Write-Output $readyMarkers[0]

  if (-not (Test-Path -LiteralPath (Join-Path $install 'zip-update-marker.txt') -PathType Leaf)) {
    throw 'ZIP update marker is missing.'
  }
  Assert-NoZipTransactionPaths 'successful ZIP update'
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
  if (($null -ne $concurrentHelper) -and (-not $concurrentHelper.HasExited)) {
    Stop-Process -Id $concurrentHelper.Id -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $concurrentHelper.Id -ErrorAction SilentlyContinue
  }
  if (($null -ne $gateParent) -and (-not $gateParent.HasExited)) {
    Stop-Process -Id $gateParent.Id -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $gateParent.Id -ErrorAction SilentlyContinue
  }
  if ($null -ne $relaunchPid) {
    Stop-Process -Id $relaunchPid -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $relaunchPid -ErrorAction SilentlyContinue
  }
  Invoke-TestUninstaller
  foreach ($transactionPath in @(Get-ZipTransactionPaths)) {
    if (Test-Path -LiteralPath $transactionPath.FullName) {
      Remove-Item -LiteralPath (Get-ValidatedCleanupPath $transactionPath.FullName) -Recurse -Force
    }
  }
  foreach ($target in @(
    $install,
    $uninstallRoot,
    $data,
    $productionOverride,
    $corruptUpdate,
    $badFixtureRoot,
    $badUpdate,
    $concurrentOutput,
    $concurrentError,
    $gateRelease
  )) {
    if (Test-Path -LiteralPath $target) {
      Remove-Item -LiteralPath (Get-ValidatedCleanupPath $target) -Recurse -Force
    }
  }
  if (Test-Path -LiteralPath $productionSentinel -PathType Leaf) {
    Remove-Item -LiteralPath $productionSentinel -Force
  }
  if ((Test-Path -LiteralPath $productionInstall -PathType Container) -and
      ((Get-ChildItem -LiteralPath $productionInstall -Force).Count -eq 0)) {
    Remove-Item -LiteralPath $productionInstall -Force
  }
}
