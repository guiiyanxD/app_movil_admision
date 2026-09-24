import 'dart:async';

import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/internaciones/presentation/pages/camara_escaneo_hc2_page.dart';
import 'package:app_movil/features/internaciones/presentation/pages/revision_ingreso_hc2_page.dart';
import 'package:app_movil/features/internaciones/presentation/providers/ingreso_hc2_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Diálogo modal que permite al operador capturar una fotografía del HC-2
/// con la cámara del dispositivo o seleccionarla de la galería multimedia.
class CapturaHC2Dialog extends ConsumerStatefulWidget {
  const CapturaHC2Dialog({super.key});

  static Future<void> mostrar(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CapturaHC2Dialog(),
    );
  }

  @override
  ConsumerState<CapturaHC2Dialog> createState() => _CapturaHC2DialogState();
}

class _CapturaHC2DialogState extends ConsumerState<CapturaHC2Dialog> {
  final ImagePicker _picker = ImagePicker();
  bool _procesando = false;
  String? _mensajeEstado;

  Future<void> _capturar(ImageSource fuente) async {
    try {
      final xfile = await _picker.pickImage(
        source: fuente,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (xfile == null) return;

      setState(() {
        _procesando = true;
        _mensajeEstado = 'Leyendo formulario con OCR...';
      });

      final ocr = ref.read(ocrServiceProvider);
      final resultado = await ocr.procesarImagenHC2(xfile.path);

      if (!mounted) return;

      // Cerrar este bottom sheet
      Navigator.of(context).pop();

      // Navegar a la pantalla de revisión con los datos obtenidos
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RevisionIngresoHC2Page(
            datosIniciales: resultado.datos,
            rutaImagen: xfile.path,
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _mensajeEstado = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo procesar la imagen: $e'),
          backgroundColor: TemaApp.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TemaApp.semilla.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: TemaApp.semilla,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo Ingreso (Form. HC-2)',
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Digitalización con OCR on-device',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Captura una fotografía nítida del formulario HC-2 o '
            'selecciónala desde la galería de tu teléfono. '
            'Los datos del paciente y la internación serán extraídos automáticamente.',
            style: tema.textTheme.bodyMedium?.copyWith(
              color: esquema.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          if (_procesando) ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _mensajeEstado ?? 'Procesando...',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: TemaApp.semilla,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            FilledButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tomar fotografía con la cámara'),
              style: FilledButton.styleFrom(
                backgroundColor: TemaApp.semilla,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const CamaraEscaneoHC2Page(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir imagen de la galería'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _capturar(ImageSource.gallery),
            ),
          ],
        ],
      ),
    );
  }
}
