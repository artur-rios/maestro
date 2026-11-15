param(
  [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = 'Stop'
$version = '6.7.1'
$expectedSha256 = '4d11e8050b6185e0d49bd9e8cc661a7a59f44959a621d31d11033124c4e8a7b0'
$url = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_1/innosetup-6.7.1.exe'
$destinationRoot = [IO.Path]::GetFullPath($Destination)
$download = Join-Path $destinationRoot "innosetup-$version.exe"
$maxDownloadAttempts = 5
$downloadRetryDelaySeconds = 15

# GitHub's release downloads fail now and then with a 5xx, which should not fail a build. A loop, because Windows
# PowerShell has no -MaximumRetryCount. The digest below still checks whatever arrives.
function Invoke-CompilerDownload {
  for ($attempt = 1; ; $attempt++) {
    try {
      Invoke-WebRequest -Uri $url -OutFile $download -UseBasicParsing
      return
    } catch {
      if ($attempt -ge $maxDownloadAttempts) {
        throw
      }
      $delay = $downloadRetryDelaySeconds * $attempt
      Write-Warning "Inno Setup download attempt $attempt of $maxDownloadAttempts failed, retrying in $delay seconds: $($_.Exception.Message)"
      Start-Sleep -Seconds $delay
    }
  }
}

function Get-ValidatedInstallPath {
  $candidate = [IO.Path]::GetFullPath((Join-Path $destinationRoot 'install'))
  $separator = [IO.Path]::DirectorySeparatorChar
  $destinationPrefix = $destinationRoot.TrimEnd(
    $separator,
    [IO.Path]::AltDirectorySeparatorChar
  ) + $separator
  if (-not $candidate.StartsWith($destinationPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Inno Setup extraction path is outside its destination: $candidate"
  }
  return $candidate
}

$validatedInstall = Get-ValidatedInstallPath
$compiler = Join-Path $validatedInstall 'ISCC.exe'

New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $download)) {
  Invoke-CompilerDownload
}
$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
  throw "Inno Setup digest mismatch: $actualSha256"
}
if (Test-Path -LiteralPath $validatedInstall) {
  Remove-Item -LiteralPath $validatedInstall -Recurse -Force
}
if (Test-Path -LiteralPath $validatedInstall) {
  throw 'Stale Inno Setup extraction could not be removed.'
}
$process = Start-Process -FilePath $download -ArgumentList @(
  '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CURRENTUSER', '/PORTABLE=1',
  ('/DIR="{0}"' -f $validatedInstall)
) -Wait -PassThru
if ($process.ExitCode -ne 0) {
  throw "Inno Setup installation failed with exit code $($process.ExitCode)."
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
  throw 'Inno Setup compiler was not installed.'
}
Write-Output ([IO.Path]::GetFullPath($compiler))
