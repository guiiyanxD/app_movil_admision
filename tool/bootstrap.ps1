<#
  Bootstrap del proyecto app_movil — Willtech / Caja Petrolera de Salud.

  Genera las carpetas de plataforma, agrega las dependencias y aplica la
  configuración de Android 10+ (minSdk 29) y de micrófono.

  Idempotente: se puede correr varias veces sin romper nada.

  Uso, desde la raíz del proyecto:
      powershell -ExecutionPolicy Bypass -File tool\bootstrap.ps1
#>

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

Write-Host "== Bootstrap app_movil ==" -ForegroundColor Cyan
Write-Host "Raiz: $raiz"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter no esta en el PATH. Instalalo y volve a correr este script."
}

flutter --version

# ── 1. Carpetas de plataforma ────────────────────────────────────────────────
# Se generan en un directorio temporal y se copian solo android/ios/windows.
# `flutter create .` sobre el proyecto pisaria lib/main.dart y el scaffold.

$plataformasFaltantes = @('android', 'ios', 'windows') |
    Where-Object { -not (Test-Path (Join-Path $raiz $_)) }

if ($plataformasFaltantes.Count -gt 0) {
    Write-Host "`n-- Generando plataformas: $($plataformasFaltantes -join ', ')" -ForegroundColor Yellow
    $tmp = Join-Path $env:TEMP "app_movil_platform_$(Get-Random)"

    flutter create --project-name app_movil --org bo.gob.cps `
        --platforms android,ios,windows --no-pub $tmp

    foreach ($p in $plataformasFaltantes) {
        Copy-Item -Path (Join-Path $tmp $p) -Destination $raiz -Recurse -Force
        Write-Host "   copiado: $p"
    }

    Remove-Item $tmp -Recurse -Force
} else {
    Write-Host "`n-- Plataformas ya presentes, se omite flutter create" -ForegroundColor DarkGray
}

# ── 2. Dependencias ──────────────────────────────────────────────────────────
# Se agregan con `flutter pub add` para que pub resuelva las versiones vigentes
# y quede el pubspec.lock como pin real. No fijar versiones a mano en el
# pubspec sin correr esto (ver README §2).

Write-Host "`n-- Agregando dependencias" -ForegroundColor Yellow

$deps = @(
    'flutter_riverpod',      # estado + inyeccion de dependencias (ADR-0002)
    'go_router',             # navegacion declarativa
    'dio',                   # cliente HTTP
    'speech_to_text',        # reconocimiento de voz (ADR-0003)
    'intl',                  # formato de fecha es-BO
    'flutter_secure_storage', # tokens JWT
    'pdf',                   # construccion del documento (SPEC-004)
    'printing'               # dialogo del sistema: imprimir, compartir, guardar
)

# PIN DELIBERADO. permission_handler 13.x arrastra permission_handler_android
# 14.x, escrito para AGP 9 / Gradle 9; este proyecto corre AGP 8.11.1 + Gradle
# 8.14 y el build del plugin falla al compilar su build.gradle.kts.
# NO cambiar por 'permission_handler' a secas: pub resolveria 13.x y volveria a
# romper el build. Ver README §7.
$depsFijadas = @(
    'permission_handler:^12.0.3'
)

# Prefijo dev: es la forma vigente; --dev quedo deprecado.
$devDeps = @(
    'dev:very_good_analysis',
    'dev:mocktail'
)

flutter pub add $deps
flutter pub add $depsFijadas
flutter pub add $devDeps
flutter pub get

# ── 3. Android 10+ (API 29) ──────────────────────────────────────────────────

Write-Host "`n-- Configurando Android (minSdk 29)" -ForegroundColor Yellow

$gradleKts    = Join-Path $raiz 'android\app\build.gradle.kts'
$gradleGroovy = Join-Path $raiz 'android\app\build.gradle'
$gradle = if (Test-Path $gradleKts) { $gradleKts }
          elseif (Test-Path $gradleGroovy) { $gradleGroovy }
          else { $null }

if ($null -eq $gradle) {
    Write-Warning "No se encontro build.gradle de la app. Fija minSdk 29 a mano."
} else {
    $contenido = Get-Content $gradle -Raw

    # Cubre las dos sintaxis: Kotlin DSL y Groovy, con o sin flutter.minSdkVersion.
    $contenido = $contenido -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 29'
    $contenido = $contenido -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 29'
    $contenido = $contenido -replace 'minSdk\s*=\s*\d+', 'minSdk = 29'
    $contenido = $contenido -replace 'minSdkVersion\s+\d+', 'minSdkVersion 29'

    Set-Content -Path $gradle -Value $contenido -NoNewline -Encoding UTF8
    Write-Host "   minSdk = 29 en $(Split-Path -Leaf $gradle)"

    if ($contenido -notmatch 'minSdk(Version)?\s*=?\s*29') {
        Write-Warning "No se pudo confirmar minSdk 29. Revisa $gradle a mano."
    }
}

# ── 4. AndroidManifest: permisos y visibilidad del reconocedor ───────────────
# El bloque <queries> es OBLIGATORIO desde Android 11 (API 30): sin el, la
# app no "ve" el servicio de reconocimiento de voz y speech_to_text reporta
# que el dispositivo no lo soporta, aunque si lo soporte.

$manifest = Join-Path $raiz 'android\app\src\main\AndroidManifest.xml'

if (-not (Test-Path $manifest)) {
    Write-Warning "No se encontro AndroidManifest.xml. Aplica el bloque a mano (README §4)."
} else {
    $xml = Get-Content $manifest -Raw

    $bloque = @'
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Android 11+ (API 30): sin este bloque la app no puede consultar el
         servicio de reconocimiento de voz y speech_to_text reporta el
         dispositivo como no soportado. Ver SPEC-002 §6.5. -->
    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>

'@

    if ($xml -match 'android\.speech\.RecognitionService') {
        Write-Host "   AndroidManifest ya configurado, se omite" -ForegroundColor DarkGray
    } else {
        $xml = $xml -replace '(?m)^(\s*)<application', "$bloque`$1<application"
        Set-Content -Path $manifest -Value $xml -NoNewline -Encoding UTF8
        Write-Host "   permisos + <queries> inyectados en AndroidManifest.xml"
    }
}

# ── 5. iOS: descripciones de uso ─────────────────────────────────────────────
# Sin estas claves la app crashea al pedir microfono, y App Store la rechaza.

$plist = Join-Path $raiz 'ios\Runner\Info.plist'

if (Test-Path $plist) {
    $info = Get-Content $plist -Raw
    if ($info -match 'NSMicrophoneUsageDescription') {
        Write-Host "   Info.plist ya configurado, se omite" -ForegroundColor DarkGray
    } else {
        $claves = @'
	<key>NSMicrophoneUsageDescription</key>
	<string>La aplicacion usa el microfono para dictar las cifras del censo diario.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>La aplicacion convierte a texto las cifras que usted dicta para llenar el censo diario.</string>
'@
        $info = $info -replace '(?m)^</dict>', "$claves</dict>"
        Set-Content -Path $plist -Value $info -NoNewline -Encoding UTF8
        Write-Host "   NSMicrophone/NSSpeechRecognition agregados a Info.plist"
    }
}

# ── 6. Verificacion ──────────────────────────────────────────────────────────

Write-Host "`n-- Analisis estatico" -ForegroundColor Yellow
flutter analyze

Write-Host "`n-- Tests" -ForegroundColor Yellow
flutter test

Write-Host "`n== Bootstrap completo ==" -ForegroundColor Green
Write-Host "Siguiente paso: flutter run -d <dispositivo Android 10+>"
