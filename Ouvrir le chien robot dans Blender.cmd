@echo off
setlocal
set "BLENDER=%~dp0.tools\blender\blender-4.5.14-windows-x64\blender.exe"
if not exist "%BLENDER%" (
  echo Blender est introuvable dans .tools\blender.
  pause
  exit /b 1
)
start "" "%BLENDER%" "%~dp0art\hound\helix_hound.blend"
