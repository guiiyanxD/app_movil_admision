import 'package:app_movil/app/tema.dart';
import 'package:app_movil/core/error/failure.dart';
import 'package:flutter/material.dart';

/// Traduce una [Failure] a algo accionable.
///
/// Renderiza `message` tanto si llegó como texto único (regla de negocio) como
/// si llegó como lista (validación campo por campo del backend).
///
/// Vive en `core/` y no dentro de una feature: `Failure` es del núcleo, y
/// cualquier pantalla que hable con el API necesita mostrarla igual. Estaba en
/// los widgets del censo diario, que era su primer uso; al aparecer el segundo
/// —reportería— la alternativa era que una feature importara de otra.
class BannerFallaApi extends StatelessWidget {
  const BannerFallaApi({required this.falla, this.alReintentar, super.key});

  final Failure falla;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final errores = falla is FallaValidacion
        ? (falla as FallaValidacion).errores
        : const <String>[];

    return Card(
      color: TemaApp.error.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: TemaApp.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    falla.mensaje,
                    style: tema.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (errores.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final error in errores)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 2),
                  child: Text('• $error', style: tema.textTheme.bodySmall),
                ),
            ],
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(falla.sugerencia, style: tema.textTheme.bodySmall),
            ),
            if (alReintentar != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: alReintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
