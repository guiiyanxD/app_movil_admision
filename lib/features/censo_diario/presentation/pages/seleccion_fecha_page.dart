import 'package:app_movil/app/widgets/menu_de_cuenta.dart';
import 'package:app_movil/core/sesion/permisos_providers.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/fecha_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/progreso_dia_page.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/progreso_mes_servicio_page.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ModoEntradaCenso {
  porDia,
  porServicio,
}

/// Punto de entrada del módulo de Censo Diario (EST-1).
///
/// Soporta dos modalidades:
/// 1. **Por Día (Diario)**: Flujo clásico para cerrar una fecha a través de
///    todos los servicios (con acceso 1-Tap a Ayer).
/// 2. **Por Servicio (Mensual)**: Flujo de cierre de mes para transcribir
///    los 30/31 días seguidos de un único servicio físico.
class SeleccionFechaPage extends ConsumerStatefulWidget {
  const SeleccionFechaPage({super.key});

  @override
  ConsumerState<SeleccionFechaPage> createState() => _SeleccionFechaPageState();
}

class _SeleccionFechaPageState extends ConsumerState<SeleccionFechaPage> {
  ModoEntradaCenso _modo = ModoEntradaCenso.porDia;

  // Estado del flujo Por Día
  DateTime? _fecha;
  bool _verificando = false;

  // Estado del flujo Por Servicio
  Servicio? _servicioSeleccionado;
  late int _mesSeleccionado;
  late int _anhoSeleccionado;

  static const _nombresMeses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _mesSeleccionado = ahora.month;
    _anhoSeleccionado = ahora.year;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hoy = FechaCenso.hoyEnBolivia();
    final ayer = hoy.subtract(const Duration(days: 1));
    final anteayer = hoy.subtract(const Duration(days: 2));

    final puedeEscribir = ref.watch(puedeEscribirProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Censo Diario — EST-1'),
        actions: const [MenuDeCuenta()],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          if (!puedeEscribir) const _AvisoSoloConsulta(),

          // ── Selector de Modo: Por Día vs Por Servicio ───────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SegmentedButton<ModoEntradaCenso>(
              segments: const [
                ButtonSegment(
                  value: ModoEntradaCenso.porDia,
                  icon: Icon(Icons.today_outlined),
                  label: Text('Por Día (Diario)'),
                ),
                ButtonSegment(
                  value: ModoEntradaCenso.porServicio,
                  icon: Icon(Icons.calendar_view_month_outlined),
                  label: Text('Por Servicio (Mes)'),
                ),
              ],
              selected: {_modo},
              onSelectionChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _modo = val.first);
              },
            ),
          ),

          if (_modo == ModoEntradaCenso.porDia) ...[
            // ── Hero Card: Cargar Ayer en 1 Tap ───────────────────────────
            Card(
              color: tema.colorScheme.primaryContainer.withValues(alpha: 0.35),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: tema.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tema.colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'MÁS COMÚN',
                            style: TextStyle(
                              color: tema.colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cierre del día anterior',
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: tema.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Censo de Ayer',
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _formatearFechaLarga(ayer),
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _verificando
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _continuarConFecha(ayer);
                            },
                      icon: _verificando && (_fecha == null || _fecha == ayer)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Cargar Ayer (1 Tap)'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Opciones rápidas de fechas alternativas ───────────────────
            Text(
              'O ELEGIR OTRA FECHA HISTÓRICA',
              style: tema.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: tema.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(
                      'Anteayer (${_dosDigitos(anteayer.day)}/${_dosDigitos(anteayer.month)})'),
                  onPressed:
                      _verificando ? null : () => _continuarConFecha(anteayer),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Abrir Calendario...'),
                  onPressed:
                      _verificando ? null : () => _abrirSelectorFecha(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Información de contexto ───────────────────────────────────
            Card(
              elevation: 0,
              color: tema.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: tema.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: tema.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Este módulo carga el censo de días ya cerrados en papel. '
                        'Por norma institucional no se permite cargar el día en curso '
                        'ni fechas futuras.',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ── Modo Por Servicio (Cierre de Mes) ──────────────────────────
            _seccionPorServicio(tema, context),
          ],
        ],
      ),
    );
  }

  Widget _seccionPorServicio(ThemeData tema, BuildContext context) {
    final serviciosAsync = ref.watch(serviciosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de Servicio Físico
        Card(
          elevation: 0,
          color: tema.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SERVICIO FÍSICO (SALA)',
                  style: tema.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: tema.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                serviciosAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    'Error al cargar servicios: $e',
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                  data: (servicios) {
                    if (servicios.isEmpty) {
                      return const Text('No hay servicios activos.');
                    }
                    final servicioActual =
                        _servicioSeleccionado ?? servicios.first;

                    return DropdownButtonFormField<Servicio>(
                      initialValue: servicioActual,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.local_hospital_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: servicios.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.nombre),
                        );
                      }).toList(),
                      onChanged: (nuevo) {
                        if (nuevo != null) {
                          HapticFeedback.selectionClick();
                          setState(() => _servicioSeleccionado = nuevo);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Selector de Mes
        Card(
          elevation: 0,
          color: tema.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERÍODO (MES Y AÑO)',
                  style: tema.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: tema.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(
                          'Este mes (${_nombresMeses[DateTime.now().month - 1]})'),
                      selected: _mesSeleccionado == DateTime.now().month &&
                          _anhoSeleccionado == DateTime.now().year,
                      onSelected: (sel) {
                        if (sel) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _mesSeleccionado = DateTime.now().month;
                            _anhoSeleccionado = DateTime.now().year;
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text(_mesAnteriorEtiqueta()),
                      selected: _esMesAnteriorSeleccionado(),
                      onSelected: (sel) {
                        if (sel) {
                          HapticFeedback.selectionClick();
                          final ahora = DateTime.now();
                          final mesAnt =
                              ahora.month == 1 ? 12 : ahora.month - 1;
                          final anhoAnt =
                              ahora.month == 1 ? ahora.year - 1 : ahora.year;
                          setState(() {
                            _mesSeleccionado = mesAnt;
                            _anhoSeleccionado = anhoAnt;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Hero Card de Acción Rápida Mensual
        serviciosAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (servicios) {
            final servicio = _servicioSeleccionado ??
                (servicios.isNotEmpty ? servicios.first : null);
            if (servicio == null) return const SizedBox.shrink();

            final nombreMes = _nombresMeses[_mesSeleccionado - 1];

            return Card(
              color: tema.colorScheme.primaryContainer.withValues(alpha: 0.35),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: tema.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tema.colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PLANILLA DE SALA',
                            style: TextStyle(
                              color: tema.colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Censo mensual',
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: tema.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      servicio.nombre,
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$nombreMes de $_anhoSeleccionado',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProgresoMesServicioPage(
                              servicio: servicio,
                              anho: _anhoSeleccionado,
                              mes: _mesSeleccionado,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('Abrir Planilla de $nombreMes (1 Tap)'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _mesAnteriorEtiqueta() {
    final ahora = DateTime.now();
    final mesAnt = ahora.month == 1 ? 12 : ahora.month - 1;
    return 'Mes anterior (${_nombresMeses[mesAnt - 1]})';
  }

  bool _esMesAnteriorSeleccionado() {
    final ahora = DateTime.now();
    final mesAnt = ahora.month == 1 ? 12 : ahora.month - 1;
    final anhoAnt = ahora.month == 1 ? ahora.year - 1 : ahora.year;
    return _mesSeleccionado == mesAnt && _anhoSeleccionado == anhoAnt;
  }

  static String _formatearFechaLarga(DateTime fecha) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }

  static String _dosDigitos(int n) => n.toString().padLeft(2, '0');

  Future<void> _abrirSelectorFecha(BuildContext context) async {
    final ahora = FechaCenso.hoyEnBolivia();
    final ayer = ahora.subtract(const Duration(days: 1));

    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? ayer,
      firstDate: DateTime(2020),
      lastDate: ayer,
      helpText: 'ELEGIR FECHA DE CENSO',
      cancelText: 'CANCELAR',
      confirmText: 'SELECCIONAR',
    );

    if (elegida != null && mounted) {
      _continuarConFecha(elegida);
    }
  }

  Future<void> _continuarConFecha(DateTime fecha) async {
    setState(() {
      _fecha = fecha;
      _verificando = true;
    });

    try {
      final cierre = await ref.read(cierreProvider(fecha).future);
      if (!mounted) return;

      if (cierre != null) {
        _mostrarDialogoFechaCerrada(cierre);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProgresoDiaPage(fecha: fecha),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _verificando = false);
      }
    }
  }

  void _mostrarDialogoFechaCerrada(dynamic cierre) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fecha ya cerrada'),
        content: Text(
          'El censo del ${_dosDigitos(_fecha!.day)}/${_dosDigitos(_fecha!.month)}/${_fecha!.year} '
          'ya fue cerrado oficialmente. Para consultarlo o imprimirlo, '
          'andá a la sección de Reportes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _AvisoSoloConsulta extends StatelessWidget {
  const _AvisoSoloConsulta();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.visibility, color: tema.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo consulta: podés revisar el avance pero no confirmar.',
                  style: tema.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
