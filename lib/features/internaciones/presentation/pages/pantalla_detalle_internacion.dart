import 'package:app_movil/features/internaciones/domain/entities/internacion_detalle.dart';
import 'package:app_movil/features/internaciones/presentation/providers/detalle_internacion_providers.dart';
import 'package:app_movil/features/internaciones/presentation/widgets/bottom_sheet_alta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class PantallaDetalleInternacion extends ConsumerWidget {
  const PantallaDetalleInternacion({
    required this.internacionId,
    super.key,
  });

  final String internacionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final asyncDetalle = ref.watch(internacionDetalleProvider(internacionId));

    return Scaffold(
      appBar: AppBar(
        title: asyncDetalle.maybeWhen(
          data: (detalle) {
            final camaActual = detalle.bedStays.isNotEmpty
                ? detalle.bedStays.last.camaCodigo
                : 'Sin cama';
            return Text('Detalle Internación - $camaActual');
          },
          orElse: () => const Text('Detalle de Internación'),
        ),
      ),
      body: asyncDetalle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: esquema.error),
                const SizedBox(height: 16),
                Text(
                  'Ocurrió un error al cargar el detalle.',
                  style: tema.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: () => ref.refresh(internacionDetalleProvider(internacionId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (detalle) => _ContenidoDetalle(detalle: detalle),
      ),
    );
  }
}

class _ContenidoDetalle extends StatelessWidget {
  const _ContenidoDetalle({required this.detalle});

  final InternacionDetalle detalle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CabeceraPaciente(paciente: detalle.paciente),
        const SizedBox(height: 16),
        _TarjetaInformacionIngreso(detalle: detalle),
        const SizedBox(height: 24),
        Text(
          'Línea de Tiempo de Traslados',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _TimelineTraslados(bedStays: detalle.bedStays),
        const SizedBox(height: 32),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => BottomSheetAltaMedica(internacionId: detalle.id),
            );
          },
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Registrar Alta Médica'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CabeceraPaciente extends StatelessWidget {
  const _CabeceraPaciente({required this.paciente});

  final PacienteDetalle paciente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esMasculino = paciente.sexo?.toLowerCase() == 'masculino';
    final esFemenino = paciente.sexo?.toLowerCase() == 'femenino';

    // Determinar el color de fondo basado en el sexo
    Color colorFondo;
    Color colorTexto;
    if (esMasculino) {
      colorFondo = Colors.blue.shade50;
      colorTexto = Colors.blue.shade900;
    } else if (esFemenino) {
      colorFondo = Colors.pink.shade50;
      colorTexto = Colors.pink.shade900;
    } else {
      colorFondo = tema.colorScheme.surfaceContainerHighest;
      colorTexto = tema.colorScheme.onSurface;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorTexto.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                esMasculino ? Icons.male : (esFemenino ? Icons.female : Icons.person),
                color: colorTexto,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  paciente.nombreCompleto.toUpperCase(),
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _DatoBasico(
                icono: Icons.cake_outlined,
                etiqueta: 'Edad',
                valor: paciente.edad != null ? '${paciente.edad} años' : 'No reg.',
                color: colorTexto,
              ),
              _DatoBasico(
                icono: Icons.wc_outlined,
                etiqueta: 'Sexo',
                valor: paciente.sexo != null 
                    ? paciente.sexo![0].toUpperCase() + paciente.sexo!.substring(1).toLowerCase() 
                    : 'No especificado',
                color: colorTexto,
              ),
              _DatoBasico(
                icono: Icons.badge_outlined,
                etiqueta: 'Matrícula',
                valor: (paciente.matricula != null && paciente.matricula!.isNotEmpty)
                    ? paciente.matricula!
                    : 'No informada',
                color: colorTexto,
              ),
              if (paciente.documentoNumero != null && paciente.documentoNumero!.isNotEmpty)
                _DatoBasico(
                  icono: Icons.credit_card_outlined,
                  etiqueta: 'Documento',
                  valor: '${paciente.documentoNumero} ${paciente.documentoTipo ?? ""}'.trim(),
                  color: colorTexto,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatoBasico extends StatelessWidget {
  const _DatoBasico({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaInformacionIngreso extends StatelessWidget {
  const _TarjetaInformacionIngreso({required this.detalle});

  final InternacionDetalle detalle;

  String _formatearFecha(DateTime fecha) {
    return DateFormat("d 'de' MMMM y, HH:mm", 'es').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
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
              'Información Clínica',
              style: tema.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: tema.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            _FilaInfoInternacion(
              icono: Icons.login_outlined,
              titulo: 'Vía de ingreso',
              valor: detalle.viaIngreso.toUpperCase(),
            ),
            const SizedBox(height: 12),
            _FilaInfoInternacion(
              icono: Icons.calendar_today_outlined,
              titulo: 'Fecha de ingreso',
              valor: _formatearFecha(detalle.fechaIngreso),
            ),
            const SizedBox(height: 12),
            _FilaInfoInternacion(
              icono: Icons.medical_information_outlined,
              titulo: 'Diagnóstico Inicial',
              valor: detalle.diagnosticoInicial,
            ),
            const SizedBox(height: 12),
            _FilaInfoInternacion(
              icono: Icons.person_outline,
              titulo: 'Médico Tratante',
              valor: detalle.medicoTratante,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Text(
              'Información de Contacto',
              style: tema.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: tema.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _FilaInfoInternacion(
              icono: Icons.family_restroom_outlined,
              titulo: 'Familiar Responsable',
              valor: (detalle.familiarReferenciaNombre == null || detalle.familiarReferenciaNombre!.isEmpty) 
                  ? 'Sin información' 
                  : detalle.familiarReferenciaNombre!,
            ),
            const SizedBox(height: 12),
            _FilaInfoInternacion(
              icono: Icons.phone_outlined,
              titulo: 'Teléfono',
              valor: (detalle.familiarReferenciaTelefono == null || detalle.familiarReferenciaTelefono!.isEmpty) 
                  ? 'Sin información' 
                  : detalle.familiarReferenciaTelefono!,
            ),
            const SizedBox(height: 12),
            _FilaInfoInternacion(
              icono: Icons.location_on_outlined,
              titulo: 'Dirección',
              valor: (detalle.familiarReferenciaDireccion == null || detalle.familiarReferenciaDireccion!.isEmpty) 
                  ? 'Sin información' 
                  : detalle.familiarReferenciaDireccion!,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaInfoInternacion extends StatelessWidget {
  const _FilaInfoInternacion({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  final IconData icono;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: esquema.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: textTheme.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: esquema.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineTraslados extends StatelessWidget {
  const _TimelineTraslados({required this.bedStays});

  final List<BedStayDetalle> bedStays;

  String _formatearFechaHora(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    if (bedStays.isEmpty) {
      return const Text('No hay historial de traslados registrados.');
    }

    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final bedStaysDesc = bedStays.reversed.toList();

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: bedStaysDesc.length,
        itemBuilder: (context, index) {
          final stay = bedStaysDesc[index];
          final esActual = index == 0; // El primero en la lista descendente es el actual

          return SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nodos visuales y líneas horizontales
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 2,
                        color: index == 0 ? Colors.transparent : esquema.outlineVariant,
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: esActual ? esquema.primary : esquema.surfaceContainerHighest,
                          border: Border.all(
                            color: esActual ? esquema.primary : esquema.outline,
                            width: 2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index == bedStaysDesc.length - 1 ? Colors.transparent : esquema.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido del Step
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: esActual
                            ? esquema.primaryContainer.withValues(alpha: 0.3)
                            : esquema.surfaceContainerHighest.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: esActual
                              ? esquema.primary.withValues(alpha: 0.3)
                              : esquema.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Cama ${stay.camaCodigo}',
                                  style: tema.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: esActual ? esquema.primary : esquema.onSurface,
                                  ),
                                ),
                              ),
                              if (esActual)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: esquema.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'ACTUAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stay.servicioNombre,
                            style: tema.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Esp: ${stay.especialidadNombre}',
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: esquema.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.login_outlined, size: 14, color: esquema.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Desde: ${_formatearFechaHora(stay.creadoEn)}',
                                  style: tema.textTheme.labelSmall?.copyWith(
                                    color: esquema.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (stay.motivoCambio != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 14, color: esquema.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Motivo: ${stay.motivoCambio}',
                                    style: tema.textTheme.labelSmall?.copyWith(
                                      color: esquema.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
