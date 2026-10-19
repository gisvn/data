@echo off
chcp 65001 > nul
echo ==========================================
echo    WebGIS Local Server
echo ==========================================
echo.
echo Dang kiem tra Python...
python --version > nul 2>&1
if %errorlevel% neq 0 (
    echo [LOI] Khong tim thay Python!
    echo Vui long cai Python tai: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo [OK] Tim thay Python.
echo.
echo Dang khoi dong WebGIS Local Server...
echo Truy cap: http://localhost:8080
echo Nhan Ctrl+C de dung server.
echo.
python "%~dp0server.py"
pause
