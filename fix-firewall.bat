@echo off
echo ================================================
echo  XPerience Gaming - Firewall Fix
echo ================================================
echo.
echo This will add a firewall rule to allow port 5000
echo.

REM Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Running as Administrator... Good!
echo.

REM Delete old rule if it exists
netsh advfirewall firewall delete rule name="XPerience Gaming Backend - Port 5000" >nul 2>&1

REM Add new rule for all profiles (Public, Private, Domain)
echo Creating firewall rule for port 5000...
netsh advfirewall firewall add rule name="XPerience Gaming Backend - Port 5000" dir=in action=allow protocol=TCP localport=5000 profile=any

if %errorLevel% equ 0 (
    echo.
    echo ================================================
    echo  SUCCESS! Firewall rule created.
    echo ================================================
    echo.
    echo Your backend server on port 5000 is now accessible
    echo from your phone on ALL network types.
    echo.
    echo You can now close this window and test your app.
    echo.
) else (
    echo.
    echo ERROR: Failed to create firewall rule.
    echo Please check Windows Firewall settings manually.
    echo.
)

pause

