# Levanta PostgreSQL, SeaweedFS y el servicio de revisión de fotos con Podman y comprueba que son accesibles desde Windows.
#
#   .\scripts\dev-services.ps1          # arrancar
#   .\scripts\dev-services.ps1 -Down    # parar (los datos se conservan en volúmenes)
#
# Requiere: Podman con la máquina en marcha, podman-compose (pip install --user podman-compose) y .env.
param([switch]$Down)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$ports = 5432, 8333, 8090

function Test-Port([int]$Port) {
    $client = New-Object Net.Sockets.TcpClient
    try { return $client.ConnectAsync('127.0.0.1', $Port).Wait(1500) -and $client.Connected }
    catch { return $false }
    finally { $client.Dispose() }
}

if ($Down) { python -m podman_compose down; exit $LASTEXITCODE }
if (-not (Test-Path .env)) { throw 'Falta .env: copia .env.example a .env y rellena los valores.' }

python -m podman_compose up -d
if ($LASTEXITCODE -ne 0) { throw 'podman-compose up ha fallado (ver "Problemas conocidos con Podman en Windows" en el README).' }

Write-Host 'Esperando a que los servicios esten sanos...'
foreach ($i in 1..40) {
    $healthy = @(podman ps --filter 'label=io.podman.compose.project=pawparazzi' --format '{{.Status}}' | Where-Object { $_ -match '\(healthy\)' }).Count
    if ($healthy -ge $ports.Count) { break }
    Start-Sleep -Seconds 3
}
podman ps --filter 'label=io.podman.compose.project=pawparazzi' --format '{{.Names}}  {{.Status}}'
if ($healthy -lt $ports.Count) { throw 'Los servicios no han llegado a estado healthy.' }

# En algunas combinaciones de Podman 6 + WSL 3 los puertos publicados no llegan a localhost de Windows.
# Con "user mode networking" activado se pueden registrar en el proxy de red de la maquina (gvproxy).
foreach ($port in $ports) {
    if (Test-Port $port) { continue }
    Write-Host "El puerto $port no responde en localhost; registrando el reenvio en gvproxy..."
    $body = '{\"local\":\":' + $port + '\",\"remote\":\"192.168.127.2:' + $port + '\"}'
    podman machine ssh "curl -s -m 5 -o /dev/null -X POST http://192.168.127.1/services/forwarder/expose -d '$body'" | Out-Null
    Start-Sleep -Seconds 1
    if (-not (Test-Port $port)) {
        throw "El puerto $port sigue sin responder. Activa user-mode networking: podman machine stop; podman machine set --user-mode-networking=true; podman machine start"
    }
}
Write-Host 'Listo: PostgreSQL en localhost:5432, SeaweedFS (S3) en localhost:8333 y revision de fotos en localhost:8090.'
