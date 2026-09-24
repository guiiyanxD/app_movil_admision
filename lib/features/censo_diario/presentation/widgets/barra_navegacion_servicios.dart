import 'package:app_movil/app/tema.dart';
import 'package:app_movil/core/formato/momento_local.dart';
import 'package:flutter/material.dart';

/// Barra inferior del formulario: `(←) (Guardar servicio) (→)`.
///
/// El operador transcribe una docena de servicios seguidos. Obligarlo a
/// guardar y retroceder de pantalla en cada uno cuesta dos gestos por servicio
/// y le hace perder el hilo del papel. Las flechas eliminan ese viaje.
///
/// Las flechas **no descartan trabajo**: si hay cambios sin guardar, la
/// pantalla los resuelve antes de moverse (guarda si el censo cuadra, o
/// pregunta si no). Ver `_resolverAntesDeNavegar` en la página.
class BarraNavegacionServicios extends StatelessWidget {
  const BarraNavegacionServicios({
    required this.indice,
    required this.total,
    required this.alAnterior,
    required this.alSiguiente,
    required this.alGuardar,
    required this.guardando,
    required this.hayCambiosSinGuardar,
    this.guardadoEn,
    this.mensajeBloqueo,
    this.etiquetaProgreso,
    this.etiquetaBotonGuardar,
    this.etiquetaAnterior,
    this.etiquetaSiguiente,
    super.key,
  });

  /// Posición del servicio o día actual, base 0.
  final int indice;
  final int total;

  final String? etiquetaProgreso;
  final String? etiquetaBotonGuardar;
  final String? etiquetaAnterior;
  final String? etiquetaSiguiente;

  /// `null` deshabilita la flecha: se está en un extremo de la lista.
  final VoidCallback? alAnterior;
  final VoidCallback? alSiguiente;

  /// `null` deshabilita el guardado.
  final VoidCallback? alGuardar;

  final bool guardando;

  /// Hay trabajo en pantalla que todavía no llegó al servidor.
  final bool hayCambiosSinGuardar;

  /// Cuándo se guardó este servicio por última vez, en UTC como llega del
  /// servidor. `null` si nunca se guardó: ni en esta sesión ni antes.
  final DateTime? guardadoEn;

  /// Por qué no se puede guardar. Se muestra sobre los botones.
  final String? mensajeBloqueo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estadoGuardado = _estadoGuardado;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mensajeBloqueo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  mensajeBloqueo!,
                  style: tema.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                _Flecha(
                  icono: Icons.chevron_left,
                  etiqueta: etiquetaAnterior ?? 'Servicio anterior',
                  alTocar: alAnterior,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: guardando ? null : alGuardar,
                    icon: guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(etiquetaBotonGuardar ?? 'Guardar servicio'),
                  ),
                ),
                const SizedBox(width: 8),
                _Flecha(
                  icono: Icons.chevron_right,
                  etiqueta: etiquetaSiguiente ?? 'Servicio siguiente',
                  alTocar: alSiguiente,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // `Wrap` y no `Row`: con el nombre del día delante de la hora
            // ("Guardado ayer 18:14") la línea no entra en un teléfono angosto,
            // y cortar el estado de guardado con puntos suspensivos sería
            // ocultar justo lo que se agregó para que se viera.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                // Saber dónde está en la lista evita la sensación de estar
                // perdido a mitad de una docena de servicios idénticos.
                Text(
                  etiquetaProgreso ?? 'Servicio ${indice + 1} de $total',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (estadoGuardado != null) estadoGuardado,
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Sin guardar" / "Guardado 18:14", junto al contador de servicios.
  ///
  /// Las flechas guardan solas cuando el censo cuadra, y el cliente reportó que
  /// no lo percibía: la app le afirmaba haber guardado algo que él nunca guardó
  /// conscientemente. Un snackbar de dos segundos no alcanza para cambiarle el
  /// modelo mental a alguien que cree que solo está tipeando; un estado
  /// permanente sí (SPEC-003, D-6 y CA-09).
  ///
  /// Con el formulario intacto y nada guardado no dice nada: no hay trabajo que
  /// pueda perderse, y avisar ahí sería gritar sin motivo.
  Widget? get _estadoGuardado {
    if (hayCambiosSinGuardar) {
      return const _MarcaEstado(
        icono: Icons.edit_outlined,
        color: TemaApp.advertencia,
        texto: 'Sin guardar',
      );
    }

    final cuando = guardadoEn;
    if (cuando == null) return null;

    return _MarcaEstado(
      icono: Icons.check_circle_outline,
      color: TemaApp.exito,
      // `momentoLocal` convierte desde UTC: mostrar la hora del servidor como
      // si fuera la del hospital haría dudar de un dato correcto (D-5).
      texto: 'Guardado ${momentoLocal(cuando)}',
    );
  }
}

/// Ícono + texto, nunca solo color (SPEC-002, §8.4).
///
/// `liveRegion` para que el lector de pantalla anuncie el paso a "Guardado":
/// es justamente el momento que el operador no estaba percibiendo.
class _MarcaEstado extends StatelessWidget {
  const _MarcaEstado({
    required this.icono,
    required this.color,
    required this.texto,
  });

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: texto,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Flecha extends StatelessWidget {
  const _Flecha({
    required this.icono,
    required this.etiqueta,
    required this.alTocar,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiqueta,
      child: SizedBox(
        width: TemaApp.objetivoTactil,
        height: TemaApp.objetivoTactil,
        child: IconButton.filledTonal(
          onPressed: alTocar,
          icon: Icon(icono),
          tooltip: etiqueta,
        ),
      ),
    );
  }
}
