# Configura la conexión HÍBRIDA de la app: USB + IP LAN + túnel Cloudflare.
#
# La app se compila con API_URLS=<usb>,<ip-lan>,<túnel> y al arrancar prueba
# /api/health en cada candidato (en paralelo), usando el primero que responda:
#   1. http://localhost:3001            → USB (adb reverse)
#   2. http://<IP-LAN>:3001             → misma red WiFi
#   3. https://xxx.trycloudflare.com    → cualquier red (internet)
#
# Uso:
#   .\scripts\connect-hybrid.ps1            # prepara todo y muestra el comando
#   .\scripts\connect-hybrid.ps1 -Run       # además flutter run
#   .\scripts\connect-hybrid.ps1 -Build     # además compila APK debug e instala por USB
#   .\scripts\connect-hybrid.ps1 -NoTunnel  # omite el túnel (solo USB + IP LAN)
param(
    [switch]$Run,
    [switch]$Build,
    [switch]$NoTunnel
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path $PSScriptRoot -Parent
$candidates = @()

# --- 1. USB (adb reverse) ---
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }
$device = & $adb devices 2>$null | Select-String -Pattern "`tdevice$" | Select-Object -First 1
if ($device) {
    & $adb reverse tcp:3001 tcp:3001 | Out-Null
    $health = & $adb shell "curl -s -m 5 http://localhost:3001/api/health" 2>$null
    if ($health -match '"Service is healthy"') {
        Write-Host "[USB] OK - dispositivo alcanza vito-api por cable" -ForegroundColor Green
        $candidates += 'http://localhost:3001'
    } else {
        Write-Warning "[USB] adb reverse aplicado pero /api/health no respondió desde el teléfono."
    }
} else {
    Write-Host "[USB] Sin dispositivo USB; se omite localhost."
}

# --- 2. IP LAN ---
$adapter = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
        $_.InterfaceAlias -match 'Wi-?Fi|Ethernet' -and
        $_.InterfaceAlias -notmatch 'vEthernet|VMware|VirtualBox|WSL|Hyper-V'
    } |
    Sort-Object { if ($_.InterfaceAlias -match 'Wi-?Fi') { 0 } else { 1 } } |
    Select-Object -First 1
if ($adapter) {
    $lanUrl = "http://$($adapter.IPAddress):3001"
    $code = (curl.exe -s -o NUL -w "%{http_code}" -m 5 "$lanUrl/api/health")
    if ($code -eq '200') {
        Write-Host "[LAN] OK - $lanUrl responde" -ForegroundColor Green
    } else {
        Write-Warning "[LAN] $lanUrl respondió HTTP $code localmente (la red podría aislar dispositivos)."
    }
    $candidates += $lanUrl
}

# --- 3. Túnel Cloudflare ---
if (-not $NoTunnel) {
    Push-Location $repoRoot
    docker compose -f docker-compose.cloudflared.yml up -d | Out-Null
    Pop-Location
    Start-Sleep -Seconds 6
    $logs = docker logs vitostore-cloudflared 2>&1 | Out-String
    $m = [regex]::Matches($logs, 'https://[a-zA-Z0-9\-]+\.trycloudflare\.com')
    if ($m.Count -gt 0) {
        $tunnelUrl = $m[$m.Count - 1].Value
        $code = (curl.exe -s -o NUL -w "%{http_code}" -m 10 "$tunnelUrl/api/health")
        if ($code -eq '200') {
            Write-Host "[Túnel] OK - $tunnelUrl" -ForegroundColor Green
        } else {
            Write-Warning "[Túnel] $tunnelUrl respondió HTTP $code (¿Norton VPN activo? cloudflared necesita TLS al puerto 7844)."
        }
        $candidates += $tunnelUrl
    } else {
        Write-Warning "[Túnel] No se encontró URL en los logs todavía; se omite el candidato."
    }
}

if ($candidates.Count -eq 0) {
    Write-Error "Ningún candidato disponible. ¿Está corriendo el stack backend (docker)?"
    exit 1
}

$apiUrls = $candidates -join ','
Write-Host ""
Write-Host "Candidatos (en orden): $apiUrls" -ForegroundColor Cyan

$appDir = Join-Path $repoRoot "vito_store_app"
if ($Run) {
    Set-Location $appDir
    flutter run --dart-define=API_URLS=$apiUrls
} elseif ($Build) {
    Set-Location $appDir
    flutter build apk --debug --dart-define=API_URLS=$apiUrls
    if ($LASTEXITCODE -eq 0 -and $device) {
        & $adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
        & $adb shell monkey -p com.vitotechnologies.vito_store_app -c android.intent.category.LAUNCHER 1 | Out-Null
        Write-Host "APK híbrido instalado y lanzado." -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "Compila/corre la app con:"
    Write-Host "  flutter run --dart-define=API_URLS=$apiUrls"
}
