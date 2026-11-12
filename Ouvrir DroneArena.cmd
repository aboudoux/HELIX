@echo off
setlocal
set "GODOT=%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot est introuvable dans .tools\godot.
  pause
  exit /b 1
)
start "" "%GODOT%" --editor --path "%~dp0DroneArena" res://missions/relay_run/mission.tscn
