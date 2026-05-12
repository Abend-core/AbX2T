@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0generate_fonts.ps1"
endlocal
