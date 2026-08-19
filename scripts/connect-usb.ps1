# Configura la conexión USB entre el dispositivo Android y el backend local.
#
# Mapea el puerto 3001 del teléfono → localhost:3001 de la PC (vito-api) vía
# `adb reverse`, de modo que la app compilada con API_URL=http://localhost:3001
# habla con el backend SOLO por el cable USB (sin internet ni túnel).
#
# Uso:
#   .\scripts\connect-usb.ps1            # configura adb reverse y verifica
#   .\scripts\connect-usb.ps1 -Run       # además corre flutter run con la URL USB
#   .\scripts\connect-usb.ps1 -Build     # además compila APK debug e instala
#
# Nota: `adb reverse` NO sobrevive reinicios/desconexiones del dispositivo.
# Vuelve a correr este script cada vez que reconectes el teléfono.
param(
    [switch]$Run,
    [switch]$Build
)

$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { $adb = "adb" }

$device = & $adb devices | Select-String -Pattern "`tdevice$" | Select-Object -First 1
if (-not $device) {
    Write-Error "No hay ningún dispositivo Android conectado por USB (revisa el cable y la depuración USB)."
    exit 1
}

& $adb reverse tcp:3001 tcp:3001 | Out-Null
Write-Host "adb reverse tcp:3001 -> tcp:3001 configurado:" -ForegroundColor Green
& $adb reverse --list

# Verificación end-to-end desde el teléfono
$health = & $adb shell "curl -s -m 8 http://localhost:3001/api/health" 2>$null
if ($health -match '"Service is healthy"') {
    Write-Host "El dispositivo alcanza vito-api por USB (HTTP 200 /api/health)" -ForegroundColor Green
} else {
    Write-Warning "No se pudo verificar /api/health desde el dispositivo. ¿Está corriendo el stack backend (docker)?"
}

$apiUrl = "http://localhost:3001"
$appDir = Join-Path $PSScriptRoot "..\vito_store_app"

if ($Run) {
    Set-Location $appDir
    flutter run --dart-define=API_URL=$apiUrl
} elseif ($Build) {
    Set-Location $appDir
    flutter build apk --debug --dart-define=API_URL=$apiUrl
    if ($LASTEXITCODE -eq 0) {
        & $adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
        & $adb shell monkey -p com.vitotechnologies.vito_store_app -c android.intent.category.LAUNCHER 1 | Out-Null
        Write-Host "APK instalado y app lanzada en el dispositivo." -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "Compila/corre la app con:"
    Write-Host "  flutter run --dart-define=API_URL=$apiUrl"
}
