param(
    [switch]$Stop,
    [switch]$Force,
    [int]$Tail = 40
)

$ErrorActionPreference = "Continue"

Write-Host "=== Blender MCP Doctor ===" -ForegroundColor Cyan
Write-Host "CWD: $PWD"
Write-Host "Time: $(Get-Date -Format s)"
Write-Host ""

$patterns = @(
    "blender-mcp",
    "blender_mcp",
    "--stdio",
    "run_server.py",
    "Blender.exe"
)

$procs = Get-CimInstance Win32_Process | Where-Object {
    $cmd = ($_.CommandLine | Out-String)
    $name = ($_.Name | Out-String)
    foreach ($p in $patterns) {
        if ($cmd -match [Regex]::Escape($p) -or $name -match [Regex]::Escape($p)) {
            return $true
        }
    }
    return $false
}

Write-Host "[1] Matched processes:" -ForegroundColor Yellow
if (-not $procs) {
    Write-Host "  none"
} else {
    $procs |
        Sort-Object ProcessId |
        Select-Object ProcessId, Name, ExecutablePath, CommandLine |
        Format-Table -AutoSize
}

Write-Host ""
Write-Host "[2] Possible MCP ports (10771, 8000, 8765):" -ForegroundColor Yellow
$ports = @(10771, 8000, 8765)
$listen = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $ports -contains $_.LocalPort }

if (-not $listen) {
    Write-Host "  none"
} else {
    $listen |
        Sort-Object LocalPort |
        Select-Object LocalAddress, LocalPort, OwningProcess, State |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "  Owner processes:" -ForegroundColor DarkYellow
    foreach ($row in $listen) {
        $p = Get-Process -Id $row.OwningProcess -ErrorAction SilentlyContinue
        if ($p) {
            Write-Host ("    {0}:{1} -> PID {2} ({3})" -f $row.LocalAddress, $row.LocalPort, $p.Id, $p.ProcessName)
        }
    }
}

Write-Host ""
Write-Host "[3] Local logs tail:" -ForegroundColor Yellow
$logPath = Join-Path $PSScriptRoot "..\logs\blender-mcp.log"
$logPath = [System.IO.Path]::GetFullPath($logPath)
if (Test-Path $logPath) {
    Get-Content $logPath -Tail $Tail -ErrorAction SilentlyContinue
} else {
    Write-Host "  log file not found: $logPath"
}

if ($Stop) {
    Write-Host ""
    Write-Host "[4] Stopping matched processes..." -ForegroundColor Yellow
    foreach ($proc in $procs) {
        try {
            if ($Force) {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
                Write-Host "  force-stopped PID $($proc.ProcessId) ($($proc.Name))"
            } else {
                Stop-Process -Id $proc.ProcessId -ErrorAction Stop
                Write-Host "  stopped PID $($proc.ProcessId) ($($proc.Name))"
            }
        } catch {
            Write-Host "  failed PID $($proc.ProcessId): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
