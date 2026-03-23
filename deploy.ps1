$ErrorActionPreference = "Stop"

$ReleaseDir = "$PSScriptRoot\app_ui\build\windows\x64\runner\Release"
$CoreManagerSrc = "$PSScriptRoot\core_manager\bin\core-manager.exe"

Write-Host ""
Write-Host "=== Troodi VPN - Build and Deploy ===" -ForegroundColor Cyan
Write-Host ""

# 1. Kill running instances
Write-Host "[1/5] Stopping running processes..." -ForegroundColor Yellow
foreach ($name in @("xray_desktop_ui", "core-manager", "xray")) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "  Stopping $name (PID: $($procs.Id -join ', '))..."
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 2

$still = Get-Process -Name "core-manager" -ErrorAction SilentlyContinue
if ($still) {
    Write-Host "  WARNING: core-manager still running (may need admin). Kill manually and re-run." -ForegroundColor Red
    exit 1
}

# 2. Build core-manager
Write-Host "[2/5] Building core-manager..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\core_manager"
go build -ldflags "-H=windowsgui" -o ".\bin\core-manager.exe" ".\cmd\core-manager"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  core-manager build FAILED" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "  OK" -ForegroundColor Green

# 3. Build Flutter app
Write-Host "[3/5] Building Flutter app..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\app_ui"
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Flutter build FAILED" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "  OK" -ForegroundColor Green

# 4. Copy core-manager.exe into Release
Write-Host "[4/5] Copying core-manager.exe to Release..." -ForegroundColor Yellow
if (-not (Test-Path $ReleaseDir)) {
    Write-Host "  Release folder not found: $ReleaseDir" -ForegroundColor Red
    exit 1
}
Copy-Item -Force $CoreManagerSrc "$ReleaseDir\core-manager.exe"
Write-Host "  OK" -ForegroundColor Green

# 5. Verify
Write-Host "[5/5] Verifying..." -ForegroundColor Yellow
$src = Get-Item $CoreManagerSrc
$dst = Get-Item "$ReleaseDir\core-manager.exe"
Write-Host "  core-manager: $($dst.Length) bytes, $($dst.LastWriteTime)"
Write-Host "  xray_desktop_ui: $((Get-Item "$ReleaseDir\xray_desktop_ui.exe").Length) bytes"

if ($src.Length -eq $dst.Length) {
    Write-Host ""
    Write-Host "Deploy OK. Launch the app:" -ForegroundColor Green
    Write-Host "  $ReleaseDir\xray_desktop_ui.exe" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "Size mismatch - something went wrong." -ForegroundColor Red
    exit 1
}
