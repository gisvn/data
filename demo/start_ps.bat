@echo off

:: ── Tự động vá PATH nếu thiếu System32 ──────────────────────
:: Kiểm tra xem chcp.com có chạy được không
where chcp >nul 2>&1
if %errorlevel% neq 0 (
    :: PATH bị thiếu – tự thêm vào cho phiên này
    set "PATH=%SystemRoot%\System32;%SystemRoot%;%SystemRoot%\System32\WindowsPowerShell\v1.0;%PATH%"
    :: Ghi luôn vào registry để lần sau không bị nữa
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "%SystemRoot%\System32;%SystemRoot%;%SystemRoot%\System32\WindowsPowerShell\v1.0" /f >nul 2>&1
    echo [OK] Da tu dong them System32 vao PATH.
)

%SystemRoot%\System32\chcp.com 65001 > nul
echo ==========================================
echo    WebGIS Local Server (PowerShell)
echo ==========================================
echo.
echo Khong can cai Python - chay bang PowerShell san co tren Windows
echo Dang khoi dong server...
echo.
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
