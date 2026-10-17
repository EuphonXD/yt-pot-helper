@echo off
chcp 65001 >nul
title YouTube Cookie Sync
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-cookies.ps1" %*
pause
