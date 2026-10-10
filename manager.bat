@echo off
rem ==============================================================================
rem MP_Mix_Manager_v0.3 - Windows 10 & 11 Native Launcher
rem Launches Mix_Archive_Manager.sh using Git Bash, MSYS2, or WSL
rem ==============================================================================
setlocal enabledelayedexpansion

rem Enable ANSI Virtual Terminal Processing for Windows Console Host
reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>nul

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
set "SCRIPT_DIR_UNIX=%SCRIPT_DIR:\=/%"

rem 1. Check for Git for Windows (bash.exe) in standard install directories
if exist "%ProgramFiles%\Git\bin\bash.exe" (
    "%ProgramFiles%\Git\bin\bash.exe" --login "%SCRIPT_DIR_UNIX%Mix_Archive_Manager.sh" %*
    if errorlevel 1 pause
    goto :eof
)
if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    "%ProgramFiles(x86)%\Git\bin\bash.exe" --login "%SCRIPT_DIR_UNIX%Mix_Archive_Manager.sh" %*
    if errorlevel 1 pause
    goto :eof
)
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" --login "%SCRIPT_DIR_UNIX%Mix_Archive_Manager.sh" %*
    if errorlevel 1 pause
    goto :eof
)

rem 2. Check for bash on system PATH (excluding WindowsApps fake stub)
for /f "delims=" %%b in ('where bash.exe 2^>nul') do (
    echo "%%b" | findstr /i "WindowsApps" >nul
    if errorlevel 1 (
        "%%b" --login "%SCRIPT_DIR_UNIX%Mix_Archive_Manager.sh" %*
        if errorlevel 1 pause
        goto :eof
    )
)

rem 3. Check for MSYS2 default paths
if exist "C:\msys64\usr\bin\bash.exe" (
    "C:\msys64\usr\bin\bash.exe" -l "%SCRIPT_DIR_UNIX%Mix_Archive_Manager.sh" %*
    if errorlevel 1 pause
    goto :eof
)

rem 4. Check for WSL (Windows Subsystem for Linux)
where wsl.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%i in ('wsl.exe wslpath "%SCRIPT_DIR%"') do set "WSL_DIR=%%i"
    wsl.exe bash -c "cd '!WSL_DIR!' && ./Mix_Archive_Manager.sh"
    if errorlevel 1 pause
    goto :eof
)

echo ==============================================================================
echo [ERROR] No compatible Bash environment found!
echo.
echo Mix Archive Manager requires a Bash shell on Windows 10 or 11.
echo Please install one of the following:
echo   - Git for Windows: https://git-scm.com/download/win (Recommended)
echo   - MSYS2:           https://www.msys2.org
echo   - WSL2:            Run 'wsl --install' in PowerShell
echo ==============================================================================
pause
