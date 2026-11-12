$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $taskRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$exportRoot = Join-Path $taskRoot 'exports\helix-web'
New-Item -ItemType Directory -Path $exportRoot -Force | Out-Null
& $godot --headless --path (Join-Path $taskRoot 'DroneArena') --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import Godot en echec.' }
& $godot --headless --path (Join-Path $taskRoot 'DroneArena') --export-release 'Web local' (Join-Path $exportRoot 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Export Web en echec. Verifier les templates Godot 4.7.2 dans AppData\Roaming\Godot\export_templates\4.7.2.stable.' }
Copy-Item -LiteralPath (Join-Path $taskRoot 'DroneArena\assets\fonts\LICENSE_DEJAVU.txt') -Destination (Join-Path $exportRoot 'LICENSE-DejaVu.txt')
Write-Host "Export termine : $exportRoot"
