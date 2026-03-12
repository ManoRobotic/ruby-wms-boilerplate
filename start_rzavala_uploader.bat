@echo off
REM Rzavala DBF Uploader - Persistent Mode Launcher
REM This script runs the uploader in a persistent loop

echo ============================================================
echo RZAVALA DBF UPLOADER - Persistent Service
echo ============================================================
echo.
echo Company: Rzavala
echo Check Interval: Every 5 minutes
echo Log File: rzavala_dbf_uploader.log
echo.
echo To stop: Press Ctrl+C
echo ============================================================
echo.

cd /d "%~dp0"

REM Run the uploader in persistent mode
rzavala_dbf_uploader.exe

pause
