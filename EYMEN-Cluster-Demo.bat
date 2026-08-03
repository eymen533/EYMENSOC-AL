@echo off
chcp 65001 >nul
title EYMEN Cluster DEMO
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js gerekli: https://nodejs.org
  start https://nodejs.org
  pause
  exit /b 1
)
node server\index.js --demo
pause
