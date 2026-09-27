@echo off
setlocal
cd /d "%~dp0"
echo ============================================
echo Ramavtalade tidsplaner v3.3.1
echo Bygger ADMIN + ANVANDARE Setup
echo ============================================
echo.
call BYGG_V3_EXE.cmd
if errorlevel 1 goto fail
set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" (
 echo Inno Setup 6 saknas. Installerar via winget...
 winget install --id JRSoftware.InnoSetup -e --accept-package-agreements --accept-source-agreements
 set "ISCC=%LocalAppData%\Programs\Inno Setup 6\ISCC.exe"
 if not exist "%ISCC%" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
)
if not exist "%ISCC%" (
 echo Kunde inte hitta Inno Setup 6.
 pause
 exit /b 1
)
if not exist installer_output mkdir installer_output
"%ISCC%" installer_user.iss
if errorlevel 1 goto fail
"%ISCC%" installer_admin.iss
if errorlevel 1 goto fail
echo.
echo KLART!
echo.
echo ANVANDARE: installer_output\Ramavtalade_tidsplaner_ANVANDARE_Setup_v3.3.1.exe
echo ADMIN:     installer_output\Ramavtalade_tidsplaner_ADMIN_Setup_v3.3.1.exe
echo.
explorer "%~dp0installer_output"
pause
exit /b 0
:fail
echo.
echo BYGGET MISSLYCKADES.
pause
exit /b 1
