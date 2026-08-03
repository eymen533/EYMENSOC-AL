@echo off
chcp 65001 >nul
title EYMEN BeamNG Cluster Bridge
cd /d "%~dp0"

echo.
echo  ========================================
echo   EYMEN BeamNG Digital Cluster
echo  ========================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo  [!] Node.js yok. Bir kez kurman lazim:
  echo      https://nodejs.org
  echo  Kurduktan sonra bu dosyaya tekrar cift tikla.
  echo.
  start https://nodejs.org
  pause
  exit /b 1
)

echo  BeamNG ayarlari:
echo    OutGauge  = 127.0.0.1   port 4444
echo    MotionSim = 127.0.0.1   port 4445
echo  Sonra Ctrl+R
echo.
echo  Telefonda uygulamaya PC IP'yi yaz.
echo  ========================================
echo.

node server\index.js
pause
