# Obtiene la URL pública del Cloudflare Quick Tunnel (vitostore-cloudflared)
# y genera el comando flutter run listo para copiar.
#
# Uso:
#   .\scripts\get-tunnel-url.ps1            # muestra la URL y el comando
#   .\scripts\get-tunnel-url.ps1 -Clip      # además copia el --dart-define al portapapeles
param(
    [switch]$Clip
)

$container = "vitostore-cloudflared"

$running = docker ps --filter "name=$container" --filter "status=running" --format "{{.Names}}"
if ($running -ne $container) {
    Write-Error "El contenedor $container no está corriendo. Levantalo con: docker compose -f docker-compose.cloudflared.yml up -d"
    exit 1
}

$logs = docker logs $container 2>&1 | Out-String
# Los logs persisten entre reinicios del contenedor: tomar la ÚLTIMA URL.
$matches = [regex]::Matches($logs, 'https://[a-zA-Z0-9\-]+\.trycloudflare\.com')
if ($matches.Count -eq 0) {
    Write-Error "No se encontró la URL del túnel en los logs. El túnel puede seguir iniciando; espera unos segundos y reintenta."
    exit 1
}

$url = $matches[$matches.Count - 1].Value
$dartDefine = "--dart-define=API_URL=$url"

Write-Host ""
Write-Host "URL del túnel:  $url"
Write-Host ""
Write-Host "Corre la app con:"
Write-Host "  flutter run $dartDefine"
Write-Host ""

if ($Clip) {
    Set-Clipboard -Value $dartDefine
    Write-Host "(--dart-define copiado al portapapeles)"
}
