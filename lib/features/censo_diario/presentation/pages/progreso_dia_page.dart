import 'package:app_movil/app/tema.dart';
import 'package:app_movil/core/error/banner_falla_api.dart';
import 'package:app_movil/core/sesion/permisos_providers.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/censo_servicio_form_page.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _FiltroServicios { todos, pendientes, descuadrados, listos }

/// Checklist y progreso del censo de una fecha.
///
/// Optimizado con Hero Card de progreso, smart action para continuar
/// el siguiente servicio pendiente con 1 tap, y filtros rápidos.
class ProgresoDiaPage extends ConsumerStatefulWidget {
  const ProgresoDiaPage({required this.fecha, super.key});

  final DateTime fecha;

  @override
  ConsumerState<ProgresoDiaPage> createState() => _ProgresoDiaPageState();
}

class _ProgresoDiaPageState extends ConsumerState<ProgresoDiaPage> {
  _FiltroServicios _filtro = _FiltroServicios.todos;

  @override
  Widget build(BuildContext context) {
    final progresoAsync = ref.watch(progresoDiaProvider(widget.fecha));
    final serviciosAsync = ref.watch(serviciosProvider);

    final progreso = progresoAsync.valueOrNull;
    final catalogo = serviciosAsync.valueOrNull;
    final error = progresoAsync.error ?? serviciosAsync.error;

    void refrescarTodo() {
      ref
        ..invalidate(progresoDiaProvider(widget.fecha))
        ..invalidate(serviciosProvider)
        ..invalidate(cargasDelDiaProvider(widget.fecha));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Censo del ${_formatear(widget.fecha)}'),
        actions: [
          IconButton(
            tooltip: 'Refrescar datos',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              refrescarTodo();
            },
          ),
        ],
      ),
      body: _cuerpo(
        context,
        progreso: progreso,
        catalogo: catalogo,
        error: error,
        refrescarTodo: refrescarTodo,
      ),
      bottomNavigationBar: progreso == null || catalogo == null
          ? null
          : _BotonConfirmar(fecha: widget.fecha, progreso: progreso),
    );
  }

  Widget _cuerpo(
    BuildContext context, {
    required ProgresoDia? progreso,
    required List<Servicio>? catalogo,
    required Object? error,
    required VoidCallback refrescarTodo,
  }) {
    if (error != null) {
      return _Error(error: error, alReintentar: refrescarTodo);
    }

    if (progreso == null || catalogo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filtrar servicios según el chip seleccionado
    final serviciosVisibles = progreso.servicios.where((s) {
      return switch (_filtro) {
        _FiltroServicios.todos => true,
        _FiltroServicios.pendientes => !s.cargado,
        _FiltroServicios.descuadrados => s.cargado && s.cuadra == false,
        _FiltroServicios.listos => s.cargado && s.cuadra == true,
      };
    }).toList();

    // Siguiente servicio pendiente para acción de 1 tap
    final siguientePendiente = progreso.pendientes.isNotEmpty
        ? progreso.pendientes.first
        : null;

    return RefreshIndicator(
      onRefresh: () async => refrescarTodo(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Hero Progress Card ───────────────────────────────────────
          _HeroProgressCard(progreso: progreso),

          // ── Smart Quick Action: Siguiente Pendiente (1 Tap) ───────────
          if (siguientePendiente != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _abrirServicio(
                      context,
                      progreso: progreso,
                      catalogo: catalogo,
                      servicioId: siguientePendiente.servicioId,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          child: const Icon(Icons.play_arrow, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SIGUIENTE PENDIENTE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                siguientePendiente.servicioNombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Filtros en Chips ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                FilterChip(
                  label: Text('Todos (${progreso.total})'),
                  selected: _filtro == _FiltroServicios.todos,
                  onSelected: (_) =>
                      setState(() => _filtro = _FiltroServicios.todos),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: progreso.pendientes.isNotEmpty
                      ? const Icon(Icons.hourglass_empty, size: 16)
                      : null,
                  label: Text('Pendientes (${progreso.pendientes.length})'),
                  selected: _filtro == _FiltroServicios.pendientes,
                  onSelected: (_) =>
                      setState(() => _filtro = _FiltroServicios.pendientes),
                ),
                const SizedBox(width: 8),
                if (progreso.desbalanceados.isNotEmpty) ...[
                  FilterChip(
                    avatar: const Icon(Icons.warning_amber,
                        size: 16, color: TemaApp.error),
                    label: Text(
                      'No cuadran (${progreso.desbalanceados.length})',
                      style: TextStyle(
                        color: _filtro == _FiltroServicios.descuadrados
                            ? null
                            : TemaApp.error,
                      ),
                    ),
                    selected: _filtro == _FiltroServicios.descuadrados,
                    onSelected: (_) =>
                        setState(() => _filtro = _FiltroServicios.descuadrados),
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text('Listos (${progreso.listos})'),
                  selected: _filtro == _FiltroServicios.listos,
                  onSelected: (_) =>
                      setState(() => _filtro = _FiltroServicios.listos),
                ),
              ],
            ),
          ),

          // ── Lista de Servicios ─────────────────────────────────────────
          if (serviciosVisibles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No hay servicios en esta sección.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            for (final servicio in serviciosVisibles)
              _FilaServicio(
                progreso: servicio,
                sinMapeo: _sinMapeo(catalogo, servicio.servicioId),
                alTocar: () {
                  HapticFeedback.selectionClick();
                  _abrirServicio(
                    context,
                    progreso: progreso,
                    catalogo: catalogo,
                    servicioId: servicio.servicioId,
                  );
                },
              ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  static bool _sinMapeo(List<Servicio> catalogo, String servicioId) {
    for (final s in catalogo) {
      if (s.id == servicioId) return !s.tieneMapeo;
    }
    return false;
  }

  Future<void> _abrirServicio(
    BuildContext context, {
    required ProgresoDia progreso,
    required List<Servicio> catalogo,
    required String servicioId,
  }) async {
    final porId = {for (final s in catalogo) s.id: s};
    final ordenados = <Servicio>[];
    for (final p in progreso.servicios) {
      final s = porId[p.servicioId];
      if (s != null) ordenados.add(s);
    }

    final indice = ordenados.indexWhere((s) => s.id == servicioId);
    if (indice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No se pudo abrir este servicio: no aparece en el catálogo.',
          ),
          action: SnackBarAction(
            label: 'Refrescar',
            onPressed: () => ref.invalidate(serviciosProvider),
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CensoServicioFormPage(
          fecha: widget.fecha,
          servicios: ordenados,
          indiceInicial: indice,
        ),
      ),
    );

    ref.invalidate(progresoDiaProvider(widget.fecha));
    ref.invalidate(cargasDelDiaProvider(widget.fecha));
  }

  static String _formatear(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}

/// Hero card que visualiza el progreso global del censo del día.
class _HeroProgressCard extends StatelessWidget {
  const _HeroProgressCard({required this.progreso});

  final ProgresoDia progreso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fraccion =
        progreso.total == 0 ? 0.0 : (progreso.listos / progreso.total).clamp(0.0, 1.0);
    final porcentaje = (fraccion * 100).toInt();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso del Día',
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${progreso.listos} de ${progreso.total} servicios listos',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$porcentaje%',
                  style: tema.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: tema.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraccion,
                minHeight: 10,
                backgroundColor: tema.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MetricaChip(
                  color: TemaApp.exito,
                  icon: Icons.check_circle_outline,
                  label: '${progreso.listos} Listos',
                ),
                const SizedBox(width: 8),
                _MetricaChip(
                  color: tema.colorScheme.onSurfaceVariant,
                  icon: Icons.hourglass_empty,
                  label: '${progreso.pendientes.length} Pendientes',
                ),
                if (progreso.desbalanceados.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _MetricaChip(
                    color: TemaApp.error,
                    icon: Icons.warning_amber,
                    label: '${progreso.desbalanceados.length} No cuadran',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricaChip extends StatelessWidget {
  const _MetricaChip({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({
    required this.progreso,
    required this.sinMapeo,
    required this.alTocar,
  });

  final ProgresoServicio progreso;
  final bool sinMapeo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (icono, color, etiqueta) = switch (progreso) {
      _ when !progreso.cargado => (
          Icons.radio_button_unchecked,
          tema.colorScheme.onSurfaceVariant,
          'Pendiente',
        ),
      _ when progreso.cuadra == false => (
          Icons.error_outline,
          TemaApp.error,
          'Cargado, no cuadra',
        ),
      _ => (Icons.check_circle, TemaApp.exito, 'Listo'),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                child: Icon(icono, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progreso.servicioNombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          etiqueta,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (sinMapeo) ...[
                          const SizedBox(width: 6),
                          const Text('·', style: TextStyle(color: TemaApp.advertencia)),
                          const SizedBox(width: 6),
                          const Text(
                            'sin mapeo',
                            style: TextStyle(
                              fontSize: 12,
                              color: TemaApp.advertencia,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonConfirmar extends ConsumerWidget {
  const _BotonConfirmar({required this.fecha, required this.progreso});

  final DateTime fecha;
  final ProgresoDia progreso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puedeEscribir = ref.watch(puedeEscribirProvider);
    final habilitado = progreso.puedeConfirmar && puedeEscribir;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!habilitado)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  !puedeEscribir
                      ? 'Tu cuenta es de consulta: no podés confirmar el día.'
                      : progreso.pendientes.isNotEmpty
                          ? 'Faltan ${progreso.pendientes.length} servicios por cargar.'
                          : 'Hay servicios cargados que no cuadran con su capacidad.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: habilitado ? () => _confirmar(context, ref) : null,
                icon: const Icon(Icons.verified_outlined),
                label: const Text(
                  'Confirmar Cierre del Día',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: habilitado ? TemaApp.exito : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmar(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final confirmo = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Confirmar el día completo'),
        content: Text(
          'Se escribirán los ${progreso.total} servicios en el sistema '
          'central. Después de esto, el censo del día queda cerrado oficialmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: FilledButton.styleFrom(backgroundColor: TemaApp.exito),
            child: const Text('Confirmar Cierre'),
          ),
        ],
      ),
    );

    if (confirmo != true || !context.mounted) return;

    final repositorio = ref.read(censoRepositoryProvider);
    final resultado = await repositorio.confirmarDia(fecha);
    if (!context.mounted) return;

    resultado.fold(
      (falla) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No se pudo confirmar'),
          content: BannerFallaApi(falla: falla),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
      (confirmacion) {
        ref.invalidate(progresoDiaProvider(fecha));
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TemaApp.exito,
            content: Text(
              '¡Día confirmado con éxito! (${confirmacion.servicios} servicios)',
            ),
          ),
        );
      },
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text('', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
