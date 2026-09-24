import 'dart:async';

import 'package:app_movil/app/tema.dart';
import 'package:app_movil/app/widgets/menu_de_cuenta.dart';
import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/captura_hc2_dialog.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/detalle_cama_bottom_sheet.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/leyenda_estados_cama.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/tarjeta_cama_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla principal del Tablero de Camas e Internaciones.
///
/// Permite consultar el mapa de camas hospitalarias en tiempo real, filtrar por
/// servicio específico y buscar interactivamente por código de cama o paciente.
class TableroCamasPage extends ConsumerStatefulWidget {
  const TableroCamasPage({super.key});

  @override
  ConsumerState<TableroCamasPage> createState() => _TableroCamasPageState();
}

class _TableroCamasPageState extends ConsumerState<TableroCamasPage> {
  final _controladorBusqueda = TextEditingController();

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  void _abrirDetalleCama(CamaTablero cama) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => DetalleCamaBottomSheet(cama: cama),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    final asyncTablero = ref.watch(tableroCamasProvider);
    final camasFiltradas = ref.watch(camasFiltradasProvider);
    final servicios = ref.watch(serviciosTableroProvider);
    final servicioIdSeleccionado = ref.watch(filtroServicioIdProvider);
    final stats = ref.watch(estadisticasTableroProvider);

    // Agrupar camas filtradas por servicio para estructurar visualmente
    final mapaGrupos = <String, ({String nombre, List<CamaTablero> camas})>{};
    for (final cama in camasFiltradas) {
      final grupo = mapaGrupos[cama.servicioId] ??
          (nombre: cama.servicioNombre, camas: <CamaTablero>[]);
      grupo.camas.add(cama);
      mapaGrupos[cama.servicioId] = grupo;
    }
    final gruposPorServicio = mapaGrupos.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tablero de Camas'),
            Text(
              '${stats.ocupadas}/${stats.total} ocupadas (${stats.porcentajeOcupacion.toStringAsFixed(0)}%)',
              style: tema.textTheme.labelSmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar tablero',
            onPressed: () => ref.refresh(tableroCamasProvider),
          ),
          const MenuDeCuenta(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(tableroCamasProvider),
        child: asyncTablero.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              Center(
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: esquema.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo cargar el tablero de camas',
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: FilledButton.icon(
                  onPressed: () => ref.refresh(tableroCamasProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ),
            ],
          ),
          data: (_) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Barra de Búsqueda Interactiva ───────────────────────────
              TextField(
                controller: _controladorBusqueda,
                decoration: InputDecoration(
                  hintText: 'Buscar por cama, paciente o matrícula...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controladorBusqueda.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controladorBusqueda.clear();
                            ref.read(filtroBusquedaProvider.notifier).state =
                                '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: esquema.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (texto) {
                  ref.read(filtroBusquedaProvider.notifier).state = texto;
                  setState(() {});
                },
              ),

              const SizedBox(height: 12),

              // ── Selector de Servicio ────────────────────────────────────
              DropdownButtonFormField<String?>(
                initialValue: servicioIdSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Filtrar por Servicio',
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                  filled: true,
                  fillColor: esquema.surfaceContainerHighest.withValues(
                    alpha: 0.2,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    child: Text('Todos los servicios (${stats.total} camas)'),
                  ),
                  for (final s in servicios)
                    DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text('${s.nombre} (${s.ocupadas}/${s.total})'),
                    ),
                ],
                onChanged: (nuevoId) {
                  ref.read(filtroServicioIdProvider.notifier).state = nuevoId;
                },
              ),

              const SizedBox(height: 14),

              // ── Leyenda de Estados ──────────────────────────────────────
              const LeyendaEstadosCama(),

              const SizedBox(height: 16),

              // ── Cuadrícula de Camas por Servicio ────────────────────────
              if (gruposPorServicio.isEmpty) ...[
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 44,
                        color: esquema.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No se encontraron camas con los filtros aplicados',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: esquema.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                for (final grupo in gruposPorServicio) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            grupo.nombre,
                            style: tema.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: esquema.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: esquema.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${grupo.camas.where((c) => c.esOcupada).length}/${grupo.camas.length} camas',
                            style: tema.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Adaptativo: 4 columnas en tablet (>= 600 dp) y 2 en móvil
                      final columnas = constraints.maxWidth >= 600 ? 4 : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: grupo.camas.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnas,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.15,
                        ),
                        itemBuilder: (context, idx) {
                          final cama = grupo.camas[idx];
                          return TarjetaCamaWidget(
                            cama: cama,
                            alPresionar: _abrirDetalleCama,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CapturaHC2Dialog.mostrar(context),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Ingreso HC-2'),
        backgroundColor: TemaApp.semilla,
        foregroundColor: Colors.white,
      ),
    );
  }
}
