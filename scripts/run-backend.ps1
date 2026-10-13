# Arranca el backend cargando las variables de .env.
#
#   .\scripts\run-backend.ps1        # PostgreSQL + SeaweedFS (antes: .\scripts\dev-services.ps1)
#   .\scripts\run-backend.ps1 -H2    # sin contenedores: base de datos H2 en fichero e imágenes en disco
param([switch]$H2)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $root '.env'

if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
} elseif (-not $H2) {
    throw 'Falta .env: copia .env.example a .env y rellena los valores (o usa -H2).'
}

if ($H2) {
    $env:SPRING_PROFILES_ACTIVE = 'h2'
    $env:STORAGE_PROVIDER = 'local'
    if (-not $env:JWT_SECRET) {
        # Secreto aleatorio solo para esta ejecucion: las sesiones dejan de valer al reiniciar.
        $bytes = New-Object byte[] 48
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $env:JWT_SECRET = [Convert]::ToBase64String($bytes)
    }
}
if (-not $env:JWT_SECRET) { throw 'JWT_SECRET esta vacio en .env (minimo 32 bytes).' }

Set-Location (Join-Path $root 'backend')
& .\mvnw.cmd spring-boot:run
