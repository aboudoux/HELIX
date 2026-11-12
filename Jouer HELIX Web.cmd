@echo off
cd /d "%~dp0"
python tools\serve_web.py --open
if errorlevel 1 pause
