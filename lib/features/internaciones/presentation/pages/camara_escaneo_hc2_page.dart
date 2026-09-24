import 'dart:async';
import 'dart:io';

import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/internaciones/presentation/pages/revision_ingreso_hc2_page.dart';
import 'package:app_movil/features/internaciones/presentation/providers/ingreso_hc2_providers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Pantalla con cámara en vivo y visor rectangular guía (aspect ratio 16:10)
/// optimizada para escanear el Formulario HC-2 de la Caja Petrolera de Salud.
class CamaraEscaneoHC2Page extends ConsumerStatefulWidget {
  const CamaraEscaneoHC2Page({super.key});

  @override
  ConsumerState<CamaraEscaneoHC2Page> createState() =>
      _CamaraEscaneoHC2PageState();
}

class _CamaraEscaneoHC2PageState extends ConsumerState<CamaraEscaneoHC2Page>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _camaras = [];
  bool _inicializando = true;
  String? _errorInicializacion;
  bool _flashEncendido = false;
  bool _procesando = false;
  String? _mensajeEstado;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_inicializarCamara());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final ctrl = _controller;
    if (ctrl != null) {
      unawaited(ctrl.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      unawaited(cameraController.dispose());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_inicializarCamara());
    }
  }

  Future<void> _inicializarCamara() async {
    setState(() {
      _inicializando = true;
      _errorInicializacion = null;
    });

    try {
      _camaras = await availableCameras();
      if (_camaras.isEmpty) {
        setState(() {
          _inicializando = false;
          _errorInicializacion = 'No se detectaron cámaras en el dispositivo.';
        });
        return;
      }

      // Buscar cámara trasera
      final camaraTrasera = _camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _camaras.first,
      );

      final controller = CameraController(
        camaraTrasera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _inicializando = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _inicializando = false;
        _errorInicializacion = 'Error al inicializar cámara: ${e.description}';
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _inicializando = false;
        _errorInicializacion = 'No se pudo acceder a la cámara: $e';
      });
    }
  }

  Future<void> _alternarFlash() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    try {
      final nuevoModo = _flashEncendido ? FlashMode.off : FlashMode.torch;
      await ctrl.setFlashMode(nuevoModo);
      setState(() {
        _flashEncendido = !_flashEncendido;
      });
    } on Object catch (_) {
      // Si el sensor no soporta torch, silenciar error
    }
  }

  Rect _calcularRectVisor(Size size) {
    // Proporción aproximada del formulario HC-2 (16:10 horizontal)
    final ancho = size.width * 0.88;
    final alto = ancho / 1.55;
    final left = (size.width - ancho) / 2;
    // Ligeramente centrado hacia arriba para dar espacio a los controles inferiores
    final top = (size.height - alto) / 2 - 24;

    return Rect.fromLTWH(left, top, ancho, alto);
  }

  Future<String> _recortarImagenAlVisor(
      String imagePath, Size screenSize,) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imagePath;

      final visorRect = _calcularRectVisor(screenSize);

      // Proporciones relativas
      final relLeft = (visorRect.left / screenSize.width).clamp(0.0, 1.0);
      final relTop = (visorRect.top / screenSize.height).clamp(0.0, 1.0);
      final relWidth = (visorRect.width / screenSize.width).clamp(0.0, 1.0);
      final relHeight = (visorRect.height / screenSize.height).clamp(0.0, 1.0);

      // Margen de seguridad del 6%
      final marginX = relWidth * 0.06;
      final marginY = relHeight * 0.06;

      final cropRelX = (relLeft - marginX).clamp(0.0, 1.0);
      final cropRelY = (relTop - marginY).clamp(0.0, 1.0);
      final cropRelW = (relWidth + (marginX * 2)).clamp(0.0, 1.0 - cropRelX);
      final cropRelH = (relHeight + (marginY * 2)).clamp(0.0, 1.0 - cropRelY);

      final x = (cropRelX * decoded.width).round();
      final y = (cropRelY * decoded.height).round();
      final w = (cropRelW * decoded.width).round();
      final h = (cropRelH * decoded.height).round();

      if (w <= 100 ||
          h <= 100 ||
          x + w > decoded.width ||
          y + h > decoded.height) {
        return imagePath;
      }

      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      final croppedBytes = img.encodeJpg(cropped, quality: 92);

      final dir = file.parent;
      final croppedFile = File(
        '${dir.path}/hc2_recorte_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await croppedFile.writeAsBytes(croppedBytes);

      return croppedFile.path;
    } on Object catch (_) {
      // Si falla el procesamiento de imagen, retornar la original como fallback
      return imagePath;
    }
  }

  Future<void> _capturarYProcesar() async {
    final ctrl = _controller;
    if (_procesando || ctrl == null || !ctrl.value.isInitialized) return;

    final screenSize = MediaQuery.of(context).size;

    setState(() {
      _procesando = true;
      _mensajeEstado = 'Capturando imagen...';
    });

    try {
      await HapticFeedback.mediumImpact();
      final xFile = await ctrl.takePicture();

      setState(() {
        _mensajeEstado = 'Ajustando encuadre y leyendo texto (OCR)...';
      });

      final rutaProcesada =
          await _recortarImagenAlVisor(xFile.path, screenSize);

      final ocr = ref.read(ocrServiceProvider);
      final resultado = await ocr.procesarImagenHC2(rutaProcesada);

      if (!mounted) return;

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => RevisionIngresoHC2Page(
            datosIniciales: resultado.datos,
            rutaImagen: rutaProcesada,
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _mensajeEstado = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar la captura: $e'),
          backgroundColor: TemaApp.error,
        ),
      );
    }
  }

  Future<void> _elegirDeGaleria() async {
    if (_procesando) return;

    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );

      if (xFile == null) return;

      setState(() {
        _procesando = true;
        _mensajeEstado = 'Extrayendo datos con OCR...';
      });

      final ocr = ref.read(ocrServiceProvider);
      final resultado = await ocr.procesarImagenHC2(xFile.path);

      if (!mounted) return;

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => RevisionIngresoHC2Page(
            datosIniciales: resultado.datos,
            rutaImagen: xFile.path,
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _mensajeEstado = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar imagen de la galería: $e'),
          backgroundColor: TemaApp.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final visorRect = _calcularRectVisor(screenSize);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Preview de la cámara o estado de inicialización
          if (_inicializando)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Iniciando cámara...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else if (_errorInicializacion != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      size: 64,
                      color: Colors.white60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorInicializacion!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Elegir de Galería'),
                      style: FilledButton.styleFrom(
                        backgroundColor: TemaApp.semilla,
                      ),
                      onPressed: _elegirDeGaleria,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: _inicializarCamara,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else if (_controller != null && _controller!.value.isInitialized) ...[
            Center(
              child: CameraPreview(_controller!),
            ),

            // 2. Máscara oscura con visor transparente y esquinas resaltadas
            CustomPaint(
              size: screenSize,
              painter: _ViewfinderOverlayPainter(
                viewfinderRect: visorRect,
                colorBorde: TemaApp.semilla,
              ),
            ),

            // 3. Indicaciones para el usuario alineadas con el visor
            Positioned(
              left: 24,
              right: 24,
              top: visorRect.top - 68,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.crop_free,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Alinee el Formulario HC-2 dentro del marco',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 32,
              right: 32,
              top: visorRect.bottom + 16,
              child: Text(
                'Procure buena luz y evite sombras o reflejos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ),
          ],

          // 4. Barra Superior (Volver, Título, Flash)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Cancelar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Escanear Formulario HC-2',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _flashEncendido ? Icons.flash_on : Icons.flash_off,
                        color: _flashEncendido ? Colors.amber : Colors.white,
                      ),
                      tooltip: _flashEncendido
                          ? 'Apagar flash'
                          : 'Encender linterna',
                      onPressed: _controller != null &&
                              _controller!.value.isInitialized
                          ? _alternarFlash
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Barra Inferior de Controles (Galería, Obturador)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón Galería
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                      ),
                      tooltip: 'Elegir imagen de galería',
                      onPressed: _procesando ? null : _elegirDeGaleria,
                    ),

                    // Botón Obturador Central
                    GestureDetector(
                      onTap: _procesando ? null : _capturarYProcesar,
                      child: Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: TemaApp.semilla,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),

                    // Espaciador balanceador
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 6. Overlay de Procesamiento OCR
          if (_procesando)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: TemaApp.semilla,
                        strokeWidth: 3.5,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _mensajeEstado ?? 'Procesando...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Extrayendo matrícula, datos y servicio',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Painter que dibuja un fondo oscuro semi-translúcido sobre toda la pantalla
/// y perfora un rectángulo redondeado con bordes resaltados en las esquinas.
class _ViewfinderOverlayPainter extends CustomPainter {
  _ViewfinderOverlayPainter({
    required this.viewfinderRect,
    required this.colorBorde,
  });

  final Rect viewfinderRect;
  final Color colorBorde;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fondo oscurecido con recorte transparente
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(viewfinderRect, const Radius.circular(16)),
      );

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(overlayPath, backgroundPaint);

    // 2. Borde sutil del marco
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(viewfinderRect, const Radius.circular(16)),
      borderPaint,
    );

    // 3. Esquinas resaltadas (Corner Brackets)
    final cornerPaint = Paint()
      ..color = colorBorde
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const cornerRadius = 16.0;
    final r = viewfinderRect;

    final path = Path()
      // Superior Izquierda
      ..moveTo(r.left, r.top + cornerLength)
      ..lineTo(r.left, r.top + cornerRadius)
      ..arcToPoint(
        Offset(r.left + cornerRadius, r.top),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(r.left + cornerLength, r.top)
      // Superior Derecha
      ..moveTo(r.right - cornerLength, r.top)
      ..lineTo(r.right - cornerRadius, r.top)
      ..arcToPoint(
        Offset(r.right, r.top + cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(r.right, r.top + cornerLength)
      // Inferior Izquierda
      ..moveTo(r.left, r.bottom - cornerLength)
      ..lineTo(r.left, r.bottom - cornerRadius)
      ..arcToPoint(
        Offset(r.left + cornerRadius, r.bottom),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(r.left + cornerLength, r.bottom)
      // Inferior Derecha
      ..moveTo(r.right - cornerLength, r.bottom)
      ..lineTo(r.right - cornerRadius, r.bottom)
      ..arcToPoint(
        Offset(r.right, r.bottom - cornerRadius),
        radius: const Radius.circular(cornerRadius),
      )
      ..lineTo(r.right, r.bottom - cornerLength);

    canvas.drawPath(path, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.viewfinderRect != viewfinderRect ||
        oldDelegate.colorBorde != colorBorde;
  }
}
