@echo off
setlocal
set "BLENDER=%~dp0.tools\blender\blender-4.5.14-windows-x64\blender.exe"
if not exist "%BLENDER%" (
  echo Blender est introuvable dans .tools\blender.
  pause
  exit /b 1
)
echo Export du decor enregistre dans Blender vers les trois GLB du jeu...
"%BLENDER%" --background "%~dp0art\arena\helix_arena.blend" --python-exit-code 1 --python "%~dp0art\arena\export_arena.py"
if errorlevel 1 (
  echo Echec de l'export. Consultez le message ci-dessus.
  pause
  exit /b 1
)
echo Export termine. Revenez dans Godot pour laisser les modeles se reimporter.
pause
