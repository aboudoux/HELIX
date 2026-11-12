@echo off
setlocal
set "GODOT=%~dp0.tools\godot\Godot_v4.7.2-stable_win64.exe"
start "" "%GODOT%" --path "%~dp0DroneArena" res://missions/relay_run/boss_trial.tscn
