# Configura la conexión de la app al backend vía IP de LAN (WiFi, sin cable USB).
#
# La app se compila con API_URL=http://<IP-de-esta-PC>:3001 y el dispositivo
# alcanza vito-api por la red WiFi local. Ambos deben estar en la MISMA red.
#
# Uso:
#   .\scripts\connect-ip.ps1            # detecta IP, abre firewall, verifica
#   .\scripts\connect-ip.ps1 -Run       # además flutter run con la URL por IP
#   .\scripts\connect-ip.ps1 -Build     # además compila APK debug e instala por USB
#   .\scripts\connect-ip.ps1 -Ip 192.168.1.50   # forzar una IP manual
param(
    [string]$Ip,
    [switch]$Run,
    [switch]$Build
)

# 1. Detectar IP de LAN (preferir Wi-Fi/Ethernet real; excluir adaptadores virtuales)
if (-not $Ip) {
    $adapter = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and
            $_.InterfaceAlias -match 'Wi-?Fi|Ethernet' -and
            $_.InterfaceAlias -notmatch 'vEthernet|VMware|VirtualBox|WSL|Hyper-V'
        } |
        Sort-Object { if ($_.InterfaceAlias -match 'Wi-?Fi') { 0 } else { 1 } } |
        Select-Object -First 1
    if (-not $adapter) {
        Write-Error "No se detectó una IP de LAN. Usa -Ip para indicarla manualmente (ej. -Ip 192.168.1.50)."
        exit 1
    }
    $Ip = $adapter.IPAddress
}
$apiUrl = "http://${Ip}:3001"
Write-Host "IP de LAN detectada: $Ip  →  API_URL=$apiUrl" -ForegroundColor Green

# 2. Regla de firewall para el puerto 3001 (requiere admin; se eleva si falta)
$rule = Get-NetFirewallRule -DisplayName "VitoStoreApp API 3001" -ErrorAction SilentlyContinue
if (-not $rule) {
    Write-Host "Creando regla de firewall 'VitoStoreApp API 3001' (se pedirá permiso de administrador)..."
    try {
        Start-Process powershell -Verb RunAs -Wait -ArgumentList @(
            '-NoProfile', '-Command',
            "New-NetFirewallRule -DisplayName 'VitoStoreApp API 3001' -Direction Inbound -Protocol TCP -LocalPort 3001 -Action Allow -Profile Any | Out-Null"
        )
    } catch {
        Write-Warning "No se pudo crear la regla de firewall. Si el teléfono no conecta, ejecútala a mano como admin (ver README)."
    }
}

# 3. Verificación local
try {
    $code = (curl.exe -s -o NUL -w "%{http_code}" "$apiUrl/api/health")
    if ($code -eq '200') {
        Write-Host "vito-api responde HTTP 200 en $apiUrl" -ForegroundColor Green
    } else {
        Write-Warning "vito-api respondió HTTP $code en $apiUrl (¿está corriendo el stack Docker?)"
    }
} catch {
    Write-Warning "No se pudo verificar $apiUrl/api/health"
}

# 4. Acción opcional
$appDir = Join-Path $PSScriptRoot "..\vito_store_app"
if ($Run) {
    Set-Location $appDir
    flutter run --dart-define=API_URL=$apiUrl
} elseif ($Build) {
    Set-Location $appDir
    flutter build apk --debug --dart-define=API_URL=$apiUrl
    if ($LASTEXITCODE -eq 0) {
        $adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
        if (-not (Test-Path $adb)) { $adb = "adb" }
        & $adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
        & $adb shell monkey -p com.vitotechnologies.vito_store_app -c android.intent.category.LAUNCHER 1 | Out-Null
        Write-Host "APK instalado y app lanzada. Ya puedes desconectar el USB: la app usa $apiUrl por WiFi." -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "Compila/corre la app con:"
    Write-Host "  flutter run --dart-define=API_URL=$apiUrl"
}
