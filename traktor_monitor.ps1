<#
.SYNOPSIS
    Traktor Pro Live Monitor & Audio Recorder - Windows 10 & 11 PowerShell Launcher
.DESCRIPTION
    Launches scripts\traktor_monitor.py directly with Python 3 on Windows.
#>
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ScriptDir) {
    $ScriptDir = (Get-Location).Path
}
Set-Location $ScriptDir
$PyScript = Join-Path $ScriptDir "scripts\traktor_monitor.py"

$PythonCandidates = @(
    "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
    "$env:ProgramFiles\Python312\python.exe",
    "$env:ProgramFiles\Python311\python.exe",
    "C:\Python312\python.exe",
    "C:\Python311\python.exe"
)

$FoundPy = $null
foreach ($P in $PythonCandidates) {
    if (Test-Path $P) {
        $FoundPy = $P
        break
    }
}

if (-not $FoundPy -and (Get-Command py.exe -ErrorAction SilentlyContinue)) {
    & py.exe -3 $PyScript @args
    exit $LASTEXITCODE
}

if (-not $FoundPy) {
    $AllPy = Get-Command python.exe -All -ErrorAction SilentlyContinue
    foreach ($cmd in $AllPy) {
        if ($cmd.Source -notmatch 'WindowsApps') {
            $FoundPy = $cmd.Source
            break
        }
    }
}

if ($FoundPy) {
    & $FoundPy $PyScript @args
} else {
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host "[ERROR] Python 3 was not found in PATH or standard installation paths!" -ForegroundColor Red
    Write-Host "Please install Python 3 by running: winget install Python.Python.3.12" -ForegroundColor Yellow
    Write-Host "==============================================================================" -ForegroundColor Red
    Read-Host "Press [Enter] to exit..."
}
