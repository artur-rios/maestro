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
if (-not $package.EndsWith('.zip', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Update package must be a ZIP file.'
}
if (-not (Test-Path -LiteralPath $install -PathType Container)) {
  throw 'Installation directory is unavailable.'
}
$separator = [IO.Path]::DirectorySeparatorChar
$installPrefix = $install.TrimEnd($separator, [IO.Path]::AltDirectorySeparatorChar) + $separator
if (-not $relaunch.StartsWith($installPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Relaunch path must remain inside installation directory.'
}

$normalizedInstall = $install.TrimEnd(
  $separator,
  [IO.Path]::AltDirectorySeparatorChar
).ToUpperInvariant()
$sha256 = [Security.Cryptography.SHA256]::Create()
try {
  $mutexHash = [BitConverter]::ToString(
    $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalizedInstall))
  ).Replace('-', '')
}
finally {
  $sha256.Dispose()
}
$lockRoot = Join-Path $env:LOCALAPPDATA 'Maestro\UpdateLocks'
New-Item -ItemType Directory -Path $lockRoot -Force | Out-Null
$lockPath = Join-Path $lockRoot "$mutexHash.lock"
$lockStream = $null
try {
  try {
    $lockStream = [IO.File]::Open(
      $lockPath,
      [IO.FileMode]::OpenOrCreate,
      [IO.FileAccess]::ReadWrite,
      [IO.FileShare]::None
    )
  }
  catch [IO.IOException] {
    Write-Output 'windows-zip-update: busy'
    throw 'Another ZIP update is already running for this installation.'
  }
  Write-Output 'windows-zip-update: lock acquired'

  while (Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 250
  }

  $parent = Split-Path -Parent $install
  $leaf = Split-Path -Leaf $install
  $transactionId = [Guid]::NewGuid().ToString('N')
  # Rollback keeps the last usable installation until relaunch readiness succeeds.
  $rollback = Join-Path $parent "$leaf.rollback.$transactionId"
  $staging = Join-Path $parent "$leaf.staging.$transactionId"
  if ((Test-Path -LiteralPath $staging) -or (Test-Path -LiteralPath $rollback)) {
    throw 'Stale ZIP transaction paths could not be removed.'
  }

  $rollbackCreated = $false
  $relaunchProcess = $null
  $readiness = $null
  New-Item -ItemType Directory -Path $staging | Out-Null
  try {
    Expand-Archive -LiteralPath $package -DestinationPath $staging -Force
    Move-Item -LiteralPath $install -Destination $rollback
    $rollbackCreated = $true
    Move-Item -LiteralPath $staging -Destination $install

    $readiness = Join-Path $install ".maestro-update-ready-$transactionId.signal"
    if (Test-Path -LiteralPath $readiness) {
      throw 'ZIP update readiness path already exists.'
    }
    $relaunchProcess = Start-Process -FilePath $relaunch -ArgumentList @(
      '--maestro-update-ready', ('"{0}"' -f $readiness)
    ) -PassThru
    Write-Output "windows-zip-update: relaunched $($relaunchProcess.Id)"

    $readinessDeadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $readiness -PathType Leaf)) {
      if ($relaunchProcess.HasExited) {
        throw 'ZIP update readiness failed: relaunched process exited early.'
      }
      if ([DateTime]::UtcNow -ge $readinessDeadline) {
        throw 'ZIP update readiness timed out.'
      }
      Start-Sleep -Milliseconds 100
      $relaunchProcess.Refresh()
    }
    Write-Output "windows-zip-update: ready $($relaunchProcess.Id)"

    Remove-Item -LiteralPath $readiness -Force
    $readiness = $null
    Remove-Item -LiteralPath $rollback -Recurse -Force
    $rollbackCreated = $false
  }
  catch {
    if (($null -ne $relaunchProcess) -and (-not $relaunchProcess.HasExited)) {
      Stop-Process -Id $relaunchProcess.Id -Force
      Wait-Process -Id $relaunchProcess.Id -ErrorAction SilentlyContinue
    }
    if ($rollbackCreated) {
      if (Test-Path -LiteralPath $install) {
        Move-Item -LiteralPath $install -Destination $staging
      }
      Move-Item -LiteralPath $rollback -Destination $install
      $rollbackCreated = $false
    }
    throw
  }
  finally {
    if (($null -ne $readiness) -and (Test-Path -LiteralPath $readiness)) {
      Remove-Item -LiteralPath $readiness -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $staging) {
      Remove-Item -LiteralPath $staging -Recurse -Force
    }
  }
}
finally {
  if ($null -ne $lockStream) {
    $lockStream.Dispose()
  }
}
