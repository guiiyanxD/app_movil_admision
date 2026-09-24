import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/estilos_cama.dart';
import 'package:flutter/material.dart';

/// Leyenda horizontal que lista los 6 estados de camas con sus colores e iconos.
class LeyendaEstadosCama extends StatelessWidget {
  const LeyendaEstadosCama({super.key});

  static const List<EstadoCamaVisual> _estados = [
    EstadoCamaVisual.disponible,
    EstadoCamaVisual.ocupada,
    EstadoCamaVisual.prestada,
    EstadoCamaVisual.critica,
    EstadoCamaVisual.aislamiento,
    EstadoCamaVisual.fueraDeServicio,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final estado in _estados) ...[
            _ChipLeyenda(estado: estado),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ChipLeyenda extends StatelessWidget {
  const _ChipLeyenda({required this.estado});

  final EstadoCamaVisual estado;

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloCamaVisual.para(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: estilo.colorPrincipal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: estilo.colorPrincipal.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: estilo.colorPrincipal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            estilo.etiqueta,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: estilo.colorPrincipal,
            ),
          ),
        ],
      ),
    );
  }
}
