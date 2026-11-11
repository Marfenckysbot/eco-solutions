# Safe Eco Solutions workspace preflight
# This script intentionally does not delete, overwrite, install, commit, or push files.
# The previous bootstrap script removed existing app directories and could push directly
# to main. Use this read-only check before making deliberate changes.

$ErrorActionPreference = "Stop"

function Test-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $Name is available" -ForegroundColor Green
        return $true
    }
    Write-Host "[MISSING] $Name is not installed or not in PATH" -ForegroundColor Yellow
    return $false
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Eco Solutions safe workspace check" -ForegroundColor Cyan
Write-Host "Project: $root"

$nodeOk = Test-Command "node"
$npmOk = Test-Command "npm"
$gitOk = Test-Command "git"

$expected = @(
    "apps/api/package.json",
    "apps/admin-dashboard/package.json",
    "packages/payments/package.json",
    "docker-compose.yml"
)

foreach ($relativePath in $expected) {
    $fullPath = Join-Path $root $relativePath
    if (Test-Path $fullPath) {
        Write-Host "[FOUND] $relativePath" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $relativePath" -ForegroundColor Yellow
    }
}

if (-not ($nodeOk -and $npmOk -and $gitOk)) {
    Write-Host "Install the missing tools, then rerun this read-only check." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Preflight complete. No files were changed." -ForegroundColor Green
Write-Host "Run workspace commands only after reviewing the repository README and package scripts."
