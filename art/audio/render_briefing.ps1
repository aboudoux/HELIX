$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$toolDir = Join-Path $projectRoot '.tools/voice'
if (-not (Test-Path (Join-Path $toolDir 'node_modules/msedge-tts')) -or -not (Test-Path (Join-Path $toolDir 'node_modules/ffmpeg-static/ffmpeg.exe'))) {
    & npm.cmd install --prefix $toolDir --save-exact msedge-tts@2.1.1 ffmpeg-static@5.3.0
    if ($LASTEXITCODE -ne 0) { throw 'Installation des outils de synthèse impossible.' }
}
& node (Join-Path $PSScriptRoot 'render_neural_briefing.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Synthèse de la voix française impossible.' }
