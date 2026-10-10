<#
.SYNOPSIS
    MP_Mix_Manager_v0.3 - Windows PowerShell Launcher
.DESCRIPTION
    Launches Mix Archive Manager within Git Bash, MSYS2, or WSL2.
#>
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ScriptDir) {
    $ScriptDir = (Get-Location).Path
}
Set-Location $ScriptDir
$UnixScriptDir = $ScriptDir.Replace('\', '/')

$GitBashPaths = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "C:\msys64\usr\bin\bash.exe"
)

$FoundBash = $null
foreach ($Path in $GitBashPaths) {
    if (Test-Path $Path) {
        $FoundBash = $Path
        break
    }
}

if (-not $FoundBash) {
    $AllBash = Get-Command bash.exe -All -ErrorAction SilentlyContinue
    foreach ($cmd in $AllBash) {
        if ($cmd.Source -notmatch 'WindowsApps') {
            $FoundBash = $cmd.Source
            break
        }
    }
}

try {
    if ($FoundBash) {
        & $FoundBash --login "$UnixScriptDir/Mix_Archive_Manager.sh" @args
    } elseif (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        $WslDir = (wsl.exe wslpath -a $UnixScriptDir).Trim()
        & wsl.exe bash -c "cd '$WslDir' && ./Mix_Archive_Manager.sh"
    } else {
        Write-Host "==============================================================================" -ForegroundColor Red
        Write-Host "[ERROR] No compatible Bash environment found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Mix Archive Manager requires a Bash shell on Windows 10 or 11." -ForegroundColor Yellow
        Write-Host "Please install Git for Windows: https://git-scm.com/download/win" -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor Red
        Read-Host "Press [Enter] to exit..."
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] An error occurred while launching MP Mix Manager: $_" -ForegroundColor Red
    Read-Host "Press [Enter] to exit..."
}
