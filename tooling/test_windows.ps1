param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArguments
)

# The subexpression must wrap the whole member access: "$(Get-Location).Drive.Root"
# expands only the location and appends ".Drive.Root" as literal text.
$temporaryDirectory = Join-Path (Get-Location).Drive.Root 'mt'
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
  $env:TEMP = $temporaryDirectory
  $env:TMP = $temporaryDirectory
  & flutter test @FlutterArguments
  $exitCode = $LASTEXITCODE
} finally {
  $env:TEMP = $previousTemp
  $env:TMP = $previousTmp
}
exit $exitCode
