param(
  [Parameter(Mandatory = $true)][string]$Destination
)

$ErrorActionPreference = 'Stop'
$version = '6.7.1'
$expectedSha256 = '4d11e8050b6185e0d49bd9e8cc661a7a59f44959a621d31d11033124c4e8a7b0'
$url = 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_1/innosetup-6.7.1.exe'
$destinationRoot = [IO.Path]::GetFullPath($Destination)
$download = Join-Path $destinationRoot "innosetup-$version.exe"
$install = Join-Path $destinationRoot 'install'
$compiler = Join-Path $install 'ISCC.exe'

New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $download)) {
  Invoke-WebRequest -Uri $url -OutFile $download -UseBasicParsing
}
$actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $download).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
  throw "Inno Setup digest mismatch: $actualSha256"
}
if (-not (Test-Path -LiteralPath $compiler)) {
  $process = Start-Process -FilePath $download -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CURRENTUSER',
    ('/DIR="{0}"' -f $install)
  ) -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Inno Setup installation failed with exit code $($process.ExitCode)."
  }
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
  throw 'Inno Setup compiler was not installed.'
}
Write-Output ([IO.Path]::GetFullPath($compiler))
