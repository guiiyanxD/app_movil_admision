import 'package:app_movil/app/rutas.dart';
import 'package:app_movil/app/tema.dart';
import 'package:app_movil/app/widgets/menu_de_cuenta.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Pantalla principal (Dashboard / Inicio) de la aplicación móvil.
///
/// Brinda un saludo institucional personalizado al operador conectado,
/// muestra información de contexto (rol, fecha) y accesos directos
/// a los módulos del sistema (Censo Diario, Internaciones, Reportes).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({
    super.key,
    required this.onNavegarACenso,
    required this.onNavegarAReportes,
  });

  final VoidCallback onNavegarACenso;
  final VoidCallback onNavegarAReportes;

  String _obtenerSaludoHorario() {
    final hora = DateTime.now().hour;
    if (hora >= 5 && hora < 12) {
      return '¡Buenos días!';
    } else if (hora >= 12 && hora < 19) {
      return '¡Buenas tardes!';
    } else {
      return '¡Buenas noches!';
    }
  }

  String _obtenerFechaFormateada() {
    final ahora = DateTime.now();
    try {
      final formato = DateFormat("EEEE, d 'de' MMMM 'de' y", 'es');
      final texto = formato.format(ahora);
      return texto[0].toUpperCase() + texto.substring(1);
    } catch (_) {
      // Fallback si la localización no estuviese cargada
      const meses = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
      ];
      return '${ahora.day} de ${meses[ahora.month - 1]} de ${ahora.year}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final sesion = ref.watch(sesionActivaProvider);
    final nombreUsuario = sesion?.usuario.nombreCompleto ?? 'Operador';
    final rolEtiqueta = sesion?.rol.etiqueta ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admisión — CPS'),
        actions: const [MenuDeCuenta()],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // ── Tarjeta Hero de Saludo y Contexto ──────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  esquema.primary,
                  Color.lerp(esquema.primary, Colors.black, 0.2) ??
                      esquema.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: esquema.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: esquema.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_hospital,
                            size: 14,
                            color: esquema.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Caja Petrolera de Salud',
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: esquema.onPrimary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: esquema.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        rolEtiqueta,
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: esquema.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _obtenerSaludoHorario(),
                  style: tema.textTheme.titleMedium?.copyWith(
                    color: esquema.onPrimary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombreUsuario,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    color: esquema.onPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: esquema.onPrimary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _obtenerFechaFormateada(),
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: esquema.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Título de Sección ──────────────────────────────────────────
          Text(
            'Módulos del Sistema',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: esquema.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Acceso directo a las herramientas hospitalarias disponibles:',
            style: tema.textTheme.bodySmall?.copyWith(
              color: esquema.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // ── Tarjeta: Censo Diario ───────────────────────────────────────
          _TarjetaModulo(
            icono: Icons.assignment_outlined,
            colorIcono: TemaApp.semilla,
            titulo: 'Censo Diario — EST-1',
            descripcion:
                'Carga diaria por fecha o vaciado mensual histórico por servicio.',
            etiquetaBadge: 'Activo',
            colorBadge: TemaApp.exito,
            alPresionar: onNavegarACenso,
          ),

          const SizedBox(height: 12),

          // ── Tarjeta: Internaciones y Tablero de Camas ──────────────────
          _TarjetaModulo(
            icono: Icons.hotel_outlined,
            colorIcono: const Color(0xFF0E7490),
            titulo: 'Internaciones y Tablero de Camas',
            descripcion:
                'Ocupación en tiempo real por servicio, camas disponibles y pacientes.',
            etiquetaBadge: 'Consulta Activa',
            colorBadge: TemaApp.semilla,
            alPresionar: () =>
                Navigator.of(context).pushNamed(Rutas.tableroCamas),
          ),

          const SizedBox(height: 12),

          // ── Tarjeta: Reportería ────────────────────────────────────────
          _TarjetaModulo(
            icono: Icons.analytics_outlined,
            colorIcono: const Color(0xFF8E24AA),
            titulo: 'Reportes y Estadísticas',
            descripcion:
                'Consolidado de censo, resumen de servicios y descarga en PDF.',
            etiquetaBadge: 'Disponible',
            colorBadge: esquema.secondary,
            alPresionar: onNavegarAReportes,
          ),

          const SizedBox(height: 12),

          // ── Tarjeta: Archivo Clínico ────────────────────────────────────
          if (sesion?.rol.name == 'archivo' || sesion?.rol.name == 'admin')
            _TarjetaModulo(
              icono: Icons.folder_shared_outlined,
              colorIcono: Colors.deepOrange,
              titulo: 'Archivo Clínico',
              descripcion: 'Gestión de solicitudes de historiales clínicos del día.',
              etiquetaBadge: 'Pendientes',
              colorBadge: Colors.orange,
              alPresionar: () => Navigator.of(context).pushNamed(Rutas.dashboardArchivo),
            ),
          
          if (sesion?.rol.name == 'archivo' || sesion?.rol.name == 'admin')
            const SizedBox(height: 12),

          // ── Tarjeta: Admisión de Historiales ─────────────────────────────
          if (sesion?.rol.name == 'operador' || sesion?.rol.name == 'admin')
            _TarjetaModulo(
              icono: Icons.library_books_outlined,
              colorIcono: Colors.teal,
              titulo: 'Historiales Clínicos',
              descripcion: 'Solicitar nuevos historiales a Archivo o recepcionar entregas.',
              etiquetaBadge: 'Activo',
              colorBadge: TemaApp.exito,
              alPresionar: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add_task),
                          title: const Text('Solicitar Historiales'),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).pushNamed(Rutas.solicitarHistoriales);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: const Text('Recepción de Historiales'),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).pushNamed(Rutas.recepcionHistoriales);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 28),

          // ── Pie informativo ────────────────────────────────────────────
          Center(
            child: Text(
              'Servicio de Admisión — Versión 0.1.0\nRegional Santa Cruz',
              textAlign: TextAlign.center,
              style: tema.textTheme.labelSmall?.copyWith(
                color: esquema.onSurfaceVariant.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarAvisoInternaciones(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final tema = Theme.of(ctx);
        final esquema = tema.colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.hotel_outlined,
                        color: Color(0xFF1E88E5),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Módulo de Internaciones',
                            style: tema.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'En fase de adaptación a la app móvil',
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
                  'Próximamente podrás gestionar directamente desde tu dispositivo:\n'
                  '• Tablero de camas con estado en tiempo real (libre, ocupada, en limpieza).\n'
                  '• Registro rápido de ingresos de pacientes.\n'
                  '• Egresos y altas hospitalarias.\n'
                  '• Traslados internos y entre servicios.',
                  style: tema.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: esquema.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tarjeta reutilizable de acceso a un módulo.
class _TarjetaModulo extends StatelessWidget {
  const _TarjetaModulo({
    required this.icono,
    required this.colorIcono,
    required this.titulo,
    required this.descripcion,
    required this.etiquetaBadge,
    required this.colorBadge,
    required this.alPresionar,
  });

  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final String descripcion;
  final String etiquetaBadge;
  final Color colorBadge;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: esquema.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          alPresionar();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorIcono.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: colorIcono, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            style: tema.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: esquema.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorBadge.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            etiquetaBadge,
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: colorBadge,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descripcion,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: esquema.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: esquema.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
