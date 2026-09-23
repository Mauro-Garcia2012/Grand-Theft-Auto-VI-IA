@echo off
rem Une las 3 partes descargadas en ViceCity-Windows-x64.zip (despues descomprimelo con el Explorador)
cd /d "%~dp0"
copy /b ViceCity-Windows-x64.zip.001 + ViceCity-Windows-x64.zip.002 + ViceCity-Windows-x64.zip.003 ViceCity-Windows-x64.zip
echo.
echo Listo: abre ViceCity-Windows-x64.zip, extrae la carpeta ViceCity y ejecuta ViceCity.exe
pause
