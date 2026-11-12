@echo off
cd /d "%~dp0"
".tools\blender\blender-4.5.14-windows-x64\blender.exe" --background "art\mission\helix_mission.blend" --python "art\mission\export_mission.py"
if errorlevel 1 (
  echo Echec de l'export. Consultez les messages ci-dessus.
  pause
  exit /b 1
)
echo Export termine. Revenez dans Godot pour laisser les modeles se reimporter.
pause
