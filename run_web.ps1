param(
    [ValidateSet('chrome', 'edge', 'web-server')]
    [string]$Device = 'chrome',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

# Compile on the project's drive instead of the system temporary directory.
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$runExitCode = 1
Push-Location $PSScriptRoot
try {
    $env:TEMP = Join-Path $PSScriptRoot '.build-temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
    & flutter run -d $Device --web-port=64165 @FlutterArguments
    $runExitCode = $LASTEXITCODE
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    Pop-Location
}
exit $runExitCode
