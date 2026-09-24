import 'dart:async';

import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/estilos_cama.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tarjeta táctil interactiva que representa una cama en el tablero.
///
/// Reproduce con precisión la experiencia visual de `TarjetaCama.tsx` de la web,
/// adaptada a ergonomía táctil (móviles y tablets).
class TarjetaCamaWidget extends StatelessWidget {
  const TarjetaCamaWidget({
    required this.cama,
    required this.alPresionar,
    super.key,
  });

  final CamaTablero cama;
  final ValueChanged<CamaTablero> alPresionar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estilo = EstiloCamaVisual.para(cama.estadoVisual);
    final fondo = estilo.resolverFondo(tema.brightness);

    final dias = cama.diasInternado;
    final esPrestada = cama.esPrestada;
    final esCritica = cama.esCritica;

    return Semantics(
      button: true,
      label: 'Cama ${cama.codigo}, ${estilo.etiqueta}'
          '${cama.esOcupada && cama.pacienteNombre != null ? ', paciente ${cama.pacienteNombre}' : ''}',
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            alPresionar(cama);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: estilo.colorPrincipal.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── Cabecera: Código + Badges de advertencia/estado ────────
                Row(
                  children: [
                    Icon(
                      Icons.bed_outlined,
                      size: 16,
                      color: estilo.colorPrincipal,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cama.codigo,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (esPrestada) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFA21CAF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 11,
                              color: Color(0xFFA21CAF),
                            ),
                            SizedBox(width: 2),
                            Text(
                              'Prestada',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA21CAF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (esCritica) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFC0392B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 11,
                              color: Color(0xFFC0392B),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${dias}d',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC0392B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // ── Cuerpo: Información de paciente o estado disponible ───
                if (cama.esOcupada) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: estilo.colorPrincipal,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cama.pacienteNombre ?? 'Paciente sin nombre',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dias == 0
                            ? 'Ingresó hoy'
                            : '$dias día${dias == 1 ? '' : 's'} internado',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: tema.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (cama.estadoBase == 'fuera_servicio' ||
                    cama.estadoBase == 'aislamiento') ...[
                  Expanded(
                    child: Center(
                      child: Icon(
                        cama.estadoBase == 'aislamiento'
                            ? Icons.shield_outlined
                            : Icons.block,
                        size: 36,
                        color: cama.estadoBase == 'aislamiento'
                            ? const Color(0xFFA84D06)
                            : const Color(0xFF587277),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cama.motivoEstado ?? estilo.etiqueta,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: estilo.colorPrincipal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cama.motivoEstado ?? estilo.etiqueta,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: estilo.colorPrincipal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cama.especialidadNombre,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: tema.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
