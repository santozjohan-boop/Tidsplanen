@echo off
setlocal
cd /d "%~dp0"
echo Bygger Ramavtalade tidsplaner v3.2...
python -m pip install --user pyinstaller reportlab python-docx pillow
if errorlevel 1 goto fail
python -m PyInstaller --noconfirm --clean --onefile --windowed --name "Ramavtalade tidsplaner" ramavtalade_tidsplaner.py
if errorlevel 1 goto fail
python -m PyInstaller --noconfirm --clean --onefile --windowed --name "Licensadmin" licensadmin.py
if errorlevel 1 goto fail
echo.
echo KLART. EXE-filerna finns i dist.
exit /b 0
:fail
echo BYGGET MISSLYCKADES.
pause
exit /b 1
