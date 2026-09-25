import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/censo_diario/domain/usecases/validar_censo_servicio.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:flutter/material.dart';

// `BannerFallaApi` se mudó a `core/error/` al aparecer su segundo consumidor
// (reportería): dejarlo acá habría obligado a una feature a importar de otra.
// Se reexporta para que las pantallas del censo diario no cambien sus imports.
export 'package:app_movil/core/error/banner_falla_api.dart';

/// Barra persistente de cuadre.
///
/// Vive fija sobre el teclado, siempre visible: es el dato que decide si el
/// formulario se puede guardar. Los tres estados se comunican con **ícono y
/// texto**, nunca solo con color.
class IndicadorCuadre extends StatelessWidget {
  const IndicadorCuadre({required this.estado, super.key});

  final CensoFormState estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final suma = estado.censo.sumaEstadosCama;
    final capacidad = estado.capacidad;

    final (color, icono, titulo, detalle) = switch (capacidad) {
      null => (
          TemaApp.advertencia,
          Icons.help_outline,
          'Cuadre sin verificar',
          'No se pudo consultar la capacidad del servicio.',
        ),
      _ when estado.cuadra => (
          TemaApp.exito,
          Icons.check_circle_outline,
          'El censo cuadra',
          '$suma de $capacidad camas',
        ),
      _ => (
          TemaApp.error,
          Icons.error_outline,
          'El censo no cuadra',
          _detalleDesvio(suma, capacidad),
        ),
    };

    return Semantics(
      liveRegion: true,
      label: '. ',
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border(
            bottom: BorderSide(
              color: color.withValues(alpha: 0.28),
              width: 1.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detalle,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _detalleDesvio(int suma, int capacidad) {
    final diferencia = suma - capacidad;
    final verbo = diferencia > 0 ? 'Sobran' : 'Faltan';
    return 'Suma $suma, capacidad $capacidad. '
        '$verbo ${diferencia.abs()} camas.';
  }
}

/// Aritmética del saldo, visible.
///
/// No se muestra solo el número esperado: se muestra la cuenta completa, para
/// que el operador pueda ubicar cuál de los movimientos está mal en vez de
/// adivinar.
class PanelSaldoEsperado extends StatelessWidget {
  const PanelSaldoEsperado({required this.estado, super.key});

  final CensoFormState estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final anterior = estado.totalDiaAnterior;

    if (anterior == null) {
      return TarjetaAviso(
        icono: Icons.info_outline,
        color: tema.colorScheme.onSurfaceVariant,
        titulo: 'Sin cierre del día anterior',
        cuerpo: 'No se puede contrastar el saldo. Durante la carga histórica '
            'es normal que falte el día previo.',
      );
    }

    final censo = estado.censo;
    final esperado = censo.saldoEsperado(anterior);
    final coincide = esperado == censo.total;

    return TarjetaAviso(
      icono: coincide ? Icons.check_circle_outline : Icons.warning_amber,
      color: coincide ? TemaApp.exito : TemaApp.advertencia,
      titulo: coincide ? 'El saldo cierra' : 'Revisá el saldo',
      cuerpo: '$anterior del día anterior '
          '+ ${censo.totalIngresos} ingresos '
          '− ${censo.totalEgresos} egresos '
          '= $esperado.\n'
          'Cargaste ${censo.total}.',
    );
  }
}

/// Lista de validaciones agrupadas por severidad.
class ListaValidaciones extends StatelessWidget {
  const ListaValidaciones({required this.validaciones, super.key});

  final List<ValidacionCenso> validaciones;

  @override
  Widget build(BuildContext context) {
    // V-05 y V-07 ya tienen su propio panel destacado: repetirlas acá sería
    // decir dos veces lo mismo en la misma pantalla.
    final mostrables =
        validaciones.where((v) => v.id != 'V-05' && v.id != 'V-07').toList();

    if (mostrables.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final v in mostrables)
          TarjetaAviso(
            icono: switch (v.severidad) {
              SeveridadValidacion.bloqueante => Icons.block,
              SeveridadValidacion.advertencia => Icons.warning_amber,
              SeveridadValidacion.informativa => Icons.info_outline,
            },
            color: switch (v.severidad) {
              SeveridadValidacion.bloqueante => TemaApp.error,
              SeveridadValidacion.advertencia => TemaApp.advertencia,
              SeveridadValidacion.informativa =>
                Theme.of(context).colorScheme.onSurfaceVariant,
            },
            titulo: switch (v.severidad) {
              SeveridadValidacion.bloqueante => 'No se puede guardar',
              SeveridadValidacion.advertencia => 'Atención',
              SeveridadValidacion.informativa => 'Para tener en cuenta',
            },
            cuerpo: v.mensaje,
          ),
      ],
    );
  }
}

/// Tarjeta de aviso: ícono, título y cuerpo sobre un fondo teñido.
///
/// Pública porque es el patrón con el que la app dice "prestá atención a esto"
/// y ya se usa para validaciones, saldo y lectura fallida. Duplicarla haría que
/// dos avisos igual de importantes se vieran distinto sin motivo.
class TarjetaAviso extends StatelessWidget {
  const TarjetaAviso({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.cuerpo,
    super.key,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String cuerpo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: tema.textTheme.labelLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(cuerpo, style: tema.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
