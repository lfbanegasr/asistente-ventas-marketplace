$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$cachePath = Join-Path $projectPath '.build-cache'
New-Item -ItemType Directory -Force -Path (Join-Path $cachePath 'tmp') | Out-Null

$env:PUB_CACHE = Join-Path $cachePath 'pub'
$env:GRADLE_USER_HOME = Join-Path $cachePath 'gradle'
$env:TEMP = Join-Path $cachePath 'tmp'
$env:TMP = Join-Path $cachePath 'tmp'

Push-Location $projectPath
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    flutter build apk --release --no-pub
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Output (Join-Path $projectPath 'build/app/outputs/flutter-apk/app-release.apk')
}
finally {
    Pop-Location
}
