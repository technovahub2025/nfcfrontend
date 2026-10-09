# Keep Gradle downloads and build temporary files on the project's drive.
$previousGradleHome = $env:GRADLE_USER_HOME
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$buildExitCode = 1
Push-Location $PSScriptRoot
try {
    $env:GRADLE_USER_HOME = Join-Path $PSScriptRoot '.gradle-user-home'
    $env:TEMP = Join-Path $PSScriptRoot '.build-temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME, $env:TEMP | Out-Null
    flutter build apk --release
    $buildExitCode = $LASTEXITCODE
} finally {
    $env:GRADLE_USER_HOME = $previousGradleHome
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    Pop-Location
}
exit $buildExitCode
