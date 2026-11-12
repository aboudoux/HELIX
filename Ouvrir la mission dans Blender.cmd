@echo off
setlocal
set "BLENDER=%~dp0.tools\blender\blender-4.5.14-windows-x64\blender.exe"
start "" "%BLENDER%" "%~dp0art\mission\helix_mission.blend"
