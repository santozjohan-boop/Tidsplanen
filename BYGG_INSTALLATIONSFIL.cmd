@echo off
setlocal
cd /d "%~dp0"
call BYGG_V3_EXE.cmd
if errorlevel 1 goto fail
set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
 echo.
 echo Inno Setup 6 saknas. Installerar via winget...
 winget install --id JRSoftware.InnoSetup -e --accept-package-agreements --accept-source-agreements
 set "ISCC=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"
 if not exist "%ISCC%" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
)
if not exist "%ISCC%" (
 echo Kunde inte hitta Inno Setup. Installera Inno Setup 6 och kor igen.
 pause
 exit /b 1
)
"%ISCC%" installer.iss
if errorlevel 1 goto fail
echo.
echo KLART: installer_output\Ramavtalade_tidsplaner_Setup_v3.3.1.exe
explorer "%~dp0installer_output"
pause
exit /b 0
:fail
echo BYGGET MISSLYCKADES.
pause
exit /b 1
