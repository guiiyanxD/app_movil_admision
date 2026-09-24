<#
.SYNOPSIS
    Arranca la app apuntando a uno de los destinos conocidos o a una IP directa.

.DESCRIPTION
    Script de arranque de desarrollo. Inyecta la URL de la API mediante --dart-define.

.EXAMPLE
    .\tool\correr.ps1                          # Arranca por defecto en equipo local (192.168.66.84)
    .\tool\correr.ps1 -Donde equipo
    .\tool\correr.ps1 -Donde hospital
    .\tool\correr.ps1 -Donde emulador
    .\tool\correr.ps1 -Donde 192.168.66.84
    .\tool\correr.ps1 -Ip 192.168.66.84
    .\tool\correr.ps1 -Listar
#>
[CmdletBinding()]
param(
    [string]$Donde = 'equipo',

    [ValidateSet('debug', 'profile', 'release')]
    [string]$Modo = 'debug',

    [string]$Dispositivo,

    [string]$Ip,

    [switch]$Listar
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Destinos conocidos.
# --------------------------------------------------------------------------
$Destinos = [ordered]@{
    'equipo' = @{
        Url         = 'http://192.168.66.74:3001'
        Descripcion = 'Equipo local (192.168.66.84)'
    }
    'hospital' = @{
        Url         = 'http://192.168.66.84:3001'
        Descripcion = 'Hospital (192.168.66.84)'
    }
    'oficinas' = @{
        Url         = 'http://192.168.100.104:3001'
        Descripcion = 'Oficinas administrativas'
    }
    'admision' = @{
        Url         = 'http://192.168.66.88:3001'
        Descripcion = 'Admisión'
    }
    'emulador' = @{
        # 10.0.2.2 es el host de la maquina visto desde el emulador de Android.
        Url         = 'http://10.0.2.2:3001'
        Descripcion = 'Emulador (host local)'
    }
}

function Normalizar-Url([string]$valor) {
    $v = $valor.Trim()
    if (-not $v.StartsWith('http://') -and -not $v.StartsWith('https://')) {
        $v = "http://$v"
    }
    # Si no tiene puerto especificado tras el host, agregar :3001
    $uri = [System.Uri]$v
    if ($uri.Port -eq 80 -and -not ($v -match ':80(/|$)')) {
        $v = "http://$($uri.Host):3001"
    }
    return $v
}

function Mostrar-Destinos {
    Write-Host ''
    Write-Host 'Destinos disponibles:' -ForegroundColor Cyan
    foreach ($clave in $Destinos.Keys) {
        $d = $Destinos[$clave]
        Write-Host ('  {0,-10} {1,-32} {2}' -f $clave, $d.Descripcion, $d.Url)
    }
    Write-Host ''
    Write-Host 'Uso:  .\tool\correr.ps1 -Donde equipo' -ForegroundColor DarkGray
    Write-Host '      .\tool\correr.ps1 -Donde hospital' -ForegroundColor DarkGray
    Write-Host '      .\tool\correr.ps1 -Donde 192.168.66.84' -ForegroundColor DarkGray
    Write-Host ''
}

if ($Listar) {
    Mostrar-Destinos
    exit 0
}

# Determinar destino efectivo
$destinoFinal = $null

if ($Ip) {
    $urlFormateada = Normalizar-Url $Ip
    $destinoFinal = @{
        Url         = $urlFormateada
        Descripcion = "IP directa ($Ip)"
    }
} elseif ($Destinos.Contains($Donde)) {
    $destinoFinal = $Destinos[$Donde]
} elseif ($Donde -match '^(\d{1,3}\.){3}\d{1,3}' -or $Donde.StartsWith('http://') -or $Donde.StartsWith('https://')) {
    $urlFormateada = Normalizar-Url $Donde
    $destinoFinal = @{
        Url         = $urlFormateada
        Descripcion = "Destino directo ($Donde)"
    }
} else {
    Write-Host ("Destino desconocido: '$Donde'") -ForegroundColor Yellow
    Mostrar-Destinos
    exit 1
}

# Ubicarse en la raiz del proyecto sin importar desde donde se invoque.
$raiz = Split-Path -Parent $PSScriptRoot
Push-Location $raiz

try {
    # Mapeo de puerto adb reverse si hay dispositivos conectados (para asegurar conexión por USB/emulador)
    try {
        if (Get-Command adb -ErrorAction SilentlyContinue) {
            $dispositivosAdb = adb devices 2>$null | Where-Object { $_ -match '\s+device$' }
            if ($dispositivosAdb) {
                adb reverse tcp:3001 tcp:3001 2>$null | Out-Null
            }
        }
    } catch {
        # Ignorar si adb no está disponible
    }

    Write-Host ''
    Write-Host ('Destino : {0}' -f $destinoFinal.Descripcion) -ForegroundColor Green
    Write-Host ('URL     : {0}' -f $destinoFinal.Url) -ForegroundColor Cyan
    Write-Host ('Modo    : {0}' -f $Modo)
    Write-Host ''

    $argumentos = @(
        'run'
        "--$Modo"
        "--dart-define=API_URL=$($destinoFinal.Url)"
        "--dart-define=API_DESTINO=$($destinoFinal.Descripcion)"
    )

    if ($Dispositivo) {
        $argumentos += @('-d', $Dispositivo)
    }

    & flutter @argumentos
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
