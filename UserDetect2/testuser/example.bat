@echo off

ping kel > nul
if /I %ERRORLEVEL% EQU 0 call :backup_kel

testuser

testuser ":HOMECOMP:"

testuser ":HOMECOMP:" "\\SPR4200\C$\Dokumente und Einstellungen\Daniel Marschall"
if /I %ERRORLEVEL% EQU 0 goto backup_spr4200_dm

testuser ":HOMECOMP:" "\\SPR4200\C$\Dokumente und Einstellungen\Ursula Marschall"
if /I %ERRORLEVEL% EQU 0 goto backup_spr4200_um

goto end

REM -----------------------

:backup_kel
echo Remote backup script for host KEL
exit

REM -----------------------

:backup_spr4200_dm
echo Backup script for Daniel Marschall at SPR4200
goto end

:backup_spr4200_um
echo Backup script for Ursula Marschall at SPR4200
goto end

:end
pause.
