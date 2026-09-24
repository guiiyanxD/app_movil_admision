import 'dart:async';
import 'dart:io';

import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:app_movil/features/internaciones/domain/entities/datos_ingreso_hc2.dart';
import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';
import 'package:app_movil/features/internaciones/presentation/providers/ingreso_hc2_providers.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Pantalla de Revisión, Corrección y Confirmación de los datos extraídos
/// del Formulario HC-2 mediante OCR.
class RevisionIngresoHC2Page extends ConsumerStatefulWidget {
  const RevisionIngresoHC2Page({
    required this.datosIniciales,
    this.rutaImagen,
    super.key,
  });

  final DatosIngresoHC2 datosIniciales;
  final String? rutaImagen;

  @override
  ConsumerState<RevisionIngresoHC2Page> createState() =>
      _RevisionIngresoHC2PageState();
}

class _RevisionIngresoHC2PageState
    extends ConsumerState<RevisionIngresoHC2Page> {
  late final TextEditingController _paternoCtrl;
  late final TextEditingController _maternoCtrl;
  late final TextEditingController _nombresCtrl;
  late final TextEditingController _matriculaCtrl;
  late final TextEditingController _carnetCtrl;
  late final TextEditingController _empresaCtrl;

  // Titular
  late final TextEditingController _paternoTitCtrl;
  late final TextEditingController _maternoTitCtrl;
  late final TextEditingController _nombresTitCtrl;
  late final TextEditingController _matriculaTitCtrl;
  late final TextEditingController _empresaTitCtrl;

  // Internación
  late final TextEditingController _medicoCtrl;
  late final TextEditingController _diagnosticoCtrl;

  late String _tipoPaciente;
  late String _sexo;
  late String _hospitalizadoPor;
  late String _responsablePago;
  late String _viaIngreso;
  DateTime? _fechaNacimiento;
  DateTime? _fechaNacimientoTitular;
  String? _sexoTitular;

  // Cama
  CamaTablero? _camaSeleccionada;
  bool _solicitarHistoriaAmarilla = false;

  @override
  void initState() {
    super.initState();
    final d = widget.datosIniciales;

    _paternoCtrl = TextEditingController(text: d.apellidoPaterno);
    _maternoCtrl = TextEditingController(text: d.apellidoMaterno ?? '');
    _nombresCtrl = TextEditingController(text: d.nombres);
    _matriculaCtrl = TextEditingController(text: d.matricula);
    _carnetCtrl = TextEditingController(text: d.carnetIdentidad ?? '');
    _empresaCtrl = TextEditingController(text: d.empresaAseguradora ?? '');

    _paternoTitCtrl =
        TextEditingController(text: d.apellidoPaternoTitular ?? '');
    _maternoTitCtrl =
        TextEditingController(text: d.apellidoMaternoTitular ?? '');
    _nombresTitCtrl = TextEditingController(text: d.nombresTitular ?? '');
    _matriculaTitCtrl = TextEditingController(text: d.matriculaTitular ?? '');
    _empresaTitCtrl = TextEditingController(
      text: d.empresaTitular ?? d.empresaAseguradora ?? '',
    );

    _medicoCtrl = TextEditingController(text: d.medicoTratante ?? '');
    _diagnosticoCtrl = TextEditingController(text: d.diagnosticoInicial ?? '');

    _tipoPaciente = d.tipoPaciente;
    _sexo = d.sexo;
    _fechaNacimiento = d.fechaNacimiento;
    _hospitalizadoPor = d.hospitalizadoPor;
    _responsablePago = d.responsablePago;
    _viaIngreso = d.tipoIngreso;

    _fechaNacimientoTitular = d.fechaNacimientoTitular;
    _sexoTitular = d.sexoTitular;
  }

  @override
  void dispose() {
    _paternoCtrl.dispose();
    _maternoCtrl.dispose();
    _nombresCtrl.dispose();
    _matriculaCtrl.dispose();
    _carnetCtrl.dispose();
    _empresaCtrl.dispose();
    _paternoTitCtrl.dispose();
    _maternoTitCtrl.dispose();
    _nombresTitCtrl.dispose();
    _matriculaTitCtrl.dispose();
    _empresaTitCtrl.dispose();
    _medicoCtrl.dispose();
    _diagnosticoCtrl.dispose();
    super.dispose();
  }

  void _evaluarCamaPorDefecto(List<CamaTablero> camas) {
    if (_camaSeleccionada != null || camas.isEmpty) return;

    final codigoHC2 = widget.datosIniciales.camaCodigo?.trim().toUpperCase();
    if (codigoHC2 == null || codigoHC2.isEmpty) return;

    // Buscar coincidencia normalizada
    for (final c in camas) {
      final cod = c.codigo.trim().toUpperCase();
      final codLimpio = cod.replaceAll('-', '');
      final hc2Limpio = codigoHC2.replaceAll('-', '');

      if (cod == codigoHC2 || codLimpio == hc2Limpio) {
        setState(() {
          _camaSeleccionada = c;
        });
        break;
      }
    }
  }

  Future<void> _confirmarIngreso({
    required Paciente? pacienteExistente,
    required Paciente? titularExistente,
  }) async {
    final cama = _camaSeleccionada;
    if (cama == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una cama para el ingreso.'),
          backgroundColor: TemaApp.error,
        ),
      );
      return;
    }

    // Regla 5: Si la cama está ocupada o no disponible, abortar estrictamente
    if (cama.esOcupada || cama.estadoVisual != EstadoCamaVisual.disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ingreso abortado: La cama ${cama.codigo} está ${cama.estadoVisual.etiqueta.toUpperCase()}. '
            'No se admiten dos pacientes en la misma cama.',
          ),
          backgroundColor: TemaApp.error,
        ),
      );
      return;
    }

    final datosActualizados = DatosIngresoHC2(
      apellidoPaterno: _paternoCtrl.text.trim().toUpperCase(),
      apellidoMaterno: _maternoCtrl.text.trim().toUpperCase().isNotEmpty
          ? _maternoCtrl.text.trim().toUpperCase()
          : null,
      nombres: _nombresCtrl.text.trim().toUpperCase(),
      matricula: _matriculaCtrl.text.trim().toUpperCase(),
      fechaNacimiento: _fechaNacimiento,
      sexo: _sexo,
      tipoPaciente: _tipoPaciente,
      regional: widget.datosIniciales.regional,
      empresaAseguradora: _empresaCtrl.text.trim().isNotEmpty
          ? _empresaCtrl.text.trim().toUpperCase()
          : null,
      carnetIdentidad: _carnetCtrl.text.trim().isNotEmpty
          ? _carnetCtrl.text.trim().toUpperCase()
          : null,
      matriculaTitular: _matriculaTitCtrl.text.trim().isNotEmpty
          ? _matriculaTitCtrl.text.trim().toUpperCase()
          : null,
      apellidoPaternoTitular: _paternoTitCtrl.text.trim().isNotEmpty
          ? _paternoTitCtrl.text.trim().toUpperCase()
          : null,
      apellidoMaternoTitular: _maternoTitCtrl.text.trim().isNotEmpty
          ? _maternoTitCtrl.text.trim().toUpperCase()
          : null,
      nombresTitular: _nombresTitCtrl.text.trim().isNotEmpty
          ? _nombresTitCtrl.text.trim().toUpperCase()
          : null,
      fechaNacimientoTitular: _fechaNacimientoTitular,
      sexoTitular: _sexoTitular,
      empresaTitular: _empresaTitCtrl.text.trim().isNotEmpty
          ? _empresaTitCtrl.text.trim().toUpperCase()
          : null,
      fechaIngreso: widget.datosIniciales.fechaIngreso,
      servicio: cama.servicioNombre,
      camaCodigo: cama.codigo,
      hospitalizadoPor: _hospitalizadoPor,
      medicoTratante: _medicoCtrl.text.trim().toUpperCase(),
      diagnosticoInicial: _diagnosticoCtrl.text.trim().toUpperCase(),
      tipoIngreso: _viaIngreso,
      responsablePago: _responsablePago,
      contactoEmergenciaNombre: widget.datosIniciales.contactoEmergenciaNombre,
      contactoEmergenciaTelefono:
          widget.datosIniciales.contactoEmergenciaTelefono,
      contactoEmergenciaDireccion:
          widget.datosIniciales.contactoEmergenciaDireccion,
    );

    final ok =
        await ref.read(registroIngresoHC2Provider.notifier).ejecutarIngreso(
              datos: datosActualizados,
              camaId: cama.id,
              especialidadId: cama.especialidadNativaId,
              solicitarHistoriaAmarilla: _solicitarHistoriaAmarilla,
              pacienteExistente: pacienteExistente,
              titularExistente: titularExistente,
            );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Ingreso registrado con éxito en Cama ${cama.codigo}!',
          ),
          backgroundColor: TemaApp.exito,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final err = ref.read(registroIngresoHC2Provider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Error al registrar ingreso hospitalario'),
          backgroundColor: TemaApp.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    final asyncCamas = ref.watch(tableroCamasProvider);
    final todasLasCamas = asyncCamas.valueOrNull ?? const [];

    // Asignar cama inicial si aún no se asignó
    if (_camaSeleccionada == null && todasLasCamas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _evaluarCamaPorDefecto(todasLasCamas);
      });
    }

    final estadoRegistro = ref.watch(registroIngresoHC2Provider);

    // Consulta de existencia previa del paciente y del titular
    final asyncPaciente = ref.watch(
      pacientePorMatriculaProvider(_matriculaCtrl.text.trim()),
    );
    final pacienteExistente = asyncPaciente.valueOrNull;

    final esBeneficiario = _tipoPaciente == 'beneficiario';
    final asyncTitular = esBeneficiario
        ? ref.watch(
            pacientePorMatriculaProvider(_matriculaTitCtrl.text.trim()),
          )
        : const AsyncValue<Paciente?>.data(null);
    final titularExistente = asyncTitular.valueOrNull;

    final formatoFecha = DateFormat('dd/MM/yyyy');

    // Validación de estado de la cama seleccionada
    final camaEsOcupada = _camaSeleccionada != null &&
        (_camaSeleccionada!.esOcupada ||
            _camaSeleccionada!.estadoVisual != EstadoCamaVisual.disponible);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de Ingreso HC-2'),
        actions: [
          if (widget.rutaImagen != null)
            IconButton(
              icon: const Icon(Icons.image_outlined),
              tooltip: 'Ver imagen capturada',
              onPressed: () => _mostrarModalImagen(context),
            ),
        ],
      ),
      body: Form(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Banner Resumen ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TemaApp.semilla.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TemaApp.semilla.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: TemaApp.semilla,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Revisa los datos extraídos por el OCR antes de registrar '
                      'el ingreso hospitalario en el sistema.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: esquema.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── SECCIÓN 1: DATOS DEL PACIENTE ────────────────────────────────
            _TarjetaSeccion(
              icono: Icons.person_outline,
              colorIcono: TemaApp.semilla,
              titulo: 'Datos del Paciente',
              subtitulo: asyncPaciente.isLoading
                  ? 'Verificando en base de datos...'
                  : (pacienteExistente != null
                      ? 'Paciente registrado en el sistema'
                      : 'Nuevo paciente — Se registrará automáticamente'),
              badgeTexto:
                  pacienteExistente != null ? 'Existe en BD' : 'Nuevo Registro',
              badgeColor: pacienteExistente != null
                  ? TemaApp.exito
                  : TemaApp.advertencia,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _matriculaCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Matrícula CPS *',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _carnetCtrl,
                          decoration: const InputDecoration(
                            labelText: 'C.I. / Documento',
                            prefixIcon: Icon(Icons.credit_card_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _paternoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Apellido Paterno *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maternoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Apellido Materno',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombresCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Nombre(s) *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _sexo,
                          decoration: const InputDecoration(labelText: 'Sexo'),
                          items: const [
                            DropdownMenuItem(
                              value: 'femenino',
                              child: Text('Femenino'),
                            ),
                            DropdownMenuItem(
                              value: 'masculino',
                              child: Text('Masculino'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _sexo = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _tipoPaciente,
                          decoration: const InputDecoration(
                            labelText: 'Tipo Paciente',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'asegurado',
                              child: Text('Asegurado (Titular)'),
                            ),
                            DropdownMenuItem(
                              value: 'beneficiario',
                              child: Text('Beneficiario (Familiar)'),
                            ),
                            DropdownMenuItem(
                              value: 'particular',
                              child: Text('Particular'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _tipoPaciente = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaNacimiento ?? DateTime(1980),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _fechaNacimiento = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha Nacimiento',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _fechaNacimiento != null
                                  ? formatoFecha.format(_fechaNacimiento!)
                                  : 'Seleccionar fecha',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _empresaCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Empresa',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── SECCIÓN 2: TITULAR (SI ES BENEFICIARIO) ─────────────────────
            if (esBeneficiario) ...[
              _TarjetaSeccion(
                icono: Icons.family_restroom_outlined,
                colorIcono: const Color(0xFF0284C7),
                titulo: 'Datos del Titular',
                subtitulo: asyncTitular.isLoading
                    ? 'Verificando titular en BD...'
                    : (titularExistente != null
                        ? 'Titular registrado en el sistema'
                        : 'Titular no registrado — Se creará automáticamente'),
                badgeTexto:
                    titularExistente != null ? 'Existe en BD' : 'Auto-Registro',
                badgeColor: titularExistente != null
                    ? TemaApp.exito
                    : TemaApp.advertencia,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _matriculaTitCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Matrícula Titular *',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _empresaTitCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Empresa Titular',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _paternoTitCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Paterno Titular',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maternoTitCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Materno Titular',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nombresTitCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nombres Titular',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── SECCIÓN 3: CAMA Y SERVICIO (CONTROL ESTRICTO) ───────────────
            _TarjetaSeccion(
              icono: Icons.hotel_outlined,
              colorIcono:
                  camaEsOcupada ? TemaApp.error : const Color(0xFF0E7490),
              titulo: 'Asignación de Cama y Servicio',
              subtitulo: 'Verificación en tiempo real del tablero hospitalario',
              badgeTexto: _camaSeleccionada == null
                  ? 'Sin Selección'
                  : (camaEsOcupada ? 'Cama No Disponible' : 'Cama Libre'),
              badgeColor: _camaSeleccionada == null
                  ? esquema.outline
                  : (camaEsOcupada ? TemaApp.error : TemaApp.exito),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (camaEsOcupada) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TemaApp.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: TemaApp.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: TemaApp.error,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'ALERTA CRÍTICA: La cama ${_camaSeleccionada?.codigo} '
                              'está ${_camaSeleccionada?.estadoVisual.etiqueta.toUpperCase()}.\n'
                              'El ingreso está BLOQUEADO para esta cama. Por norma de admisión, '
                              'no pueden coexistir dos pacientes en una misma cama.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: TemaApp.error,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  DropdownButtonFormField<CamaTablero>(
                    key: ValueKey(_camaSeleccionada?.id),
                    initialValue: _camaSeleccionada,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Cama Destino *',
                      prefixIcon: const Icon(Icons.meeting_room_outlined),
                      errorText: camaEsOcupada
                          ? 'Cama ocupada / no disponible. Selecciona otra cama disponible.'
                          : null,
                    ),
                    items: todasLasCamas.map((cama) {
                      final disponible =
                          cama.estadoVisual == EstadoCamaVisual.disponible;
                      return DropdownMenuItem<CamaTablero>(
                        value: cama,
                        child: Row(
                          children: [
                            Text(
                              cama.codigo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: disponible
                                    ? esquema.onSurface
                                    : TemaApp.error,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '(${cama.servicioNombre} • ${cama.estadoVisual.etiqueta})',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: disponible
                                      ? esquema.onSurfaceVariant
                                      : TemaApp.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (cama) {
                      setState(() => _camaSeleccionada = cama);
                    },
                  ),
                  if (_camaSeleccionada != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Servicio: ${_camaSeleccionada!.servicioNombre} • '
                      'Especialidad Nativa: ${_camaSeleccionada!.especialidadNombre}',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── SECCIÓN 4: DATOS CLÍNICOS DE LA INTERNACIÓN ──────────────────
            _TarjetaSeccion(
              icono: Icons.medical_services_outlined,
              colorIcono: const Color(0xFF7C3AED),
              titulo: 'Datos Clínicos de la Internación',
              subtitulo: 'Información registrada en el HC-2',
              badgeTexto: 'HC-2',
              badgeColor: const Color(0xFF7C3AED),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _diagnosticoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Diagnóstico de Ingreso *',
                      prefixIcon: Icon(Icons.healing_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _medicoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Médico que Interna *',
                      prefixIcon: Icon(Icons.person_pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _hospitalizadoPor,
                          decoration: const InputDecoration(
                            labelText: 'Hospitalizado por',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'enfermedad',
                              child: Text('Enfermedad'),
                            ),
                            DropdownMenuItem(
                              value: 'maternidad',
                              child: Text('Maternidad'),
                            ),
                            DropdownMenuItem(
                              value: 'emergencia',
                              child: Text('Emergencia'),
                            ),
                            DropdownMenuItem(
                              value: 'accidente_trabajo',
                              child: Text('Accidente de Trabajo'),
                            ),
                            DropdownMenuItem(
                              value: 'accidente_comun',
                              child: Text('Accidente Común'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _hospitalizadoPor = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _responsablePago,
                          decoration: const InputDecoration(
                            labelText: 'Responsable Pago',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'CPS',
                              child: Text('CPS'),
                            ),
                            DropdownMenuItem(
                              value: 'SOAT',
                              child: Text('SOAT'),
                            ),
                            DropdownMenuItem(
                              value: 'PARTICULAR',
                              child: Text('PARTICULAR'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _responsablePago = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── SECCIÓN 5: PASO INTERMEDIO: HISTORIA AMARILLA ────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.folder_shared_outlined,
                      color: Color(0xFFB45309),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitud de Historia Amarilla',
                          style: tema.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '¿Deseas solicitar la historia clínica física al archivo central?',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _solicitarHistoriaAmarilla,
                    activeTrackColor: const Color(0xFFB45309),
                    onChanged: (val) {
                      setState(() => _solicitarHistoriaAmarilla = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── ACCIONES: CANCELAR / CONFIRMAR INGRESO ────────────────────────
            if (estadoRegistro.cargando) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Registrando ingreso en el sistema...'),
                  ],
                ),
              ),
            ] else ...[
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar y Registrar Ingreso'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      camaEsOcupada ? esquema.outline : TemaApp.semilla,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: camaEsOcupada
                    ? null
                    : () => _confirmarIngreso(
                          pacienteExistente: pacienteExistente,
                          titularExistente: titularExistente,
                        ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancelar / Abortar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarModalImagen(BuildContext context) {
    if (widget.rutaImagen == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Formulario HC-2 Capturado'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              InteractiveViewer(
                child: Image.file(File(widget.rutaImagen!)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta estilizada con encabezado e insignias para cada sección.
class _TarjetaSeccion extends StatelessWidget {
  const _TarjetaSeccion({
    required this.icono,
    required this.colorIcono,
    required this.titulo,
    required this.subtitulo,
    required this.badgeTexto,
    required this.badgeColor,
    required this.child,
  });

  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final String subtitulo;
  final String badgeTexto;
  final Color badgeColor;
  final Widget child;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorIcono.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icono, color: colorIcono, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: tema.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitulo,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeTexto,
                    style: tema.textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
