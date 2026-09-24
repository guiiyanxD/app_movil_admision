import 'package:app_movil/features/internaciones/domain/entities/datos_ingreso_hc2.dart';
import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';
import 'package:app_movil/features/internaciones/domain/repositories/internaciones_repository.dart';
import 'package:app_movil/features/internaciones/domain/repositories/pacientes_repository.dart';
import 'package:app_movil/features/internaciones/domain/services/hc2_parser_service.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:app_movil/features/internaciones/presentation/services/ocr_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inyección del repositorio de pacientes (satisfecho en bootstrap).
final Provider<PacientesRepository> pacientesRepositoryProvider =
    Provider<PacientesRepository>((ref) {
  throw UnimplementedError(
    'pacientesRepositoryProvider debe ser sobreescrito en bootstrap.dart',
  );
});

/// Inyección del repositorio de internaciones (satisfecho en bootstrap).
final Provider<InternacionesRepository> internacionesRepositoryProvider =
    Provider<InternacionesRepository>((ref) {
  throw UnimplementedError(
    'internacionesRepositoryProvider debe ser sobreescrito en bootstrap.dart',
  );
});

/// Servicio de parseo algorítmico y de expresiones regulares del HC-2.
final Provider<HC2ParserService> hc2ParserServiceProvider =
    Provider<HC2ParserService>((ref) => const HC2ParserService());

/// Servicio de OCR con Google ML Kit.
final Provider<OcrService> ocrServiceProvider = Provider<OcrService>((ref) {
  final parser = ref.watch(hc2ParserServiceProvider);
  return OcrService(parserService: parser);
});

/// Consulta si el paciente detectado en el HC-2 ya existe en la BD por su matrícula.
final AutoDisposeFutureProviderFamily<Paciente?, String>
    pacientePorMatriculaProvider =
    FutureProvider.autoDispose.family<Paciente?, String>(
  (ref, matricula) async {
    if (matricula.trim().isEmpty) return null;
    final repo = ref.watch(pacientesRepositoryProvider);
    final resultado = await repo.buscarPorMatricula(matricula.trim());
    return resultado.fold(
      (falla) => null,
      (paciente) => paciente,
    );
  },
);

/// Estado de la confirmación y ejecución del ingreso hospitalario.
class EstadoRegistroIngreso {
  const EstadoRegistroIngreso({
    this.cargando = false,
    this.error,
    this.exito = false,
    this.mensaje,
    this.resultado,
  });

  final bool cargando;
  final String? error;
  final bool exito;
  final String? mensaje;
  final ResultadoIngresoHospitalario? resultado;

  EstadoRegistroIngreso copyWith({
    bool? cargando,
    String? error,
    bool? exito,
    String? mensaje,
    ResultadoIngresoHospitalario? resultado,
  }) {
    return EstadoRegistroIngreso(
      cargando: cargando ?? this.cargando,
      error: error,
      exito: exito ?? this.exito,
      mensaje: mensaje ?? this.mensaje,
      resultado: resultado ?? this.resultado,
    );
  }
}

/// Notifier que orquesta el guardado atómico del ingreso HC-2:
/// 1. Si el paciente es beneficiario y el titular no existe: crea el titular.
/// 2. Si el paciente no existe: crea el paciente.
/// 3. Crea la internación y el bed_stay asignado a la cama.
class RegistroIngresoHC2Notifier
    extends AutoDisposeNotifier<EstadoRegistroIngreso> {
  @override
  EstadoRegistroIngreso build() => const EstadoRegistroIngreso();

  Future<bool> ejecutarIngreso({
    required DatosIngresoHC2 datos,
    required String camaId,
    required String especialidadId,
    required bool solicitarHistoriaAmarilla,
    Paciente? pacienteExistente,
    Paciente? titularExistente,
  }) async {
    state = const EstadoRegistroIngreso(cargando: true);

    final pacientesRepo = ref.read(pacientesRepositoryProvider);
    final internacionesRepo = ref.read(internacionesRepositoryProvider);

    try {
      // ── Paso 1: Si es beneficiario y el titular no existe, crearlo ────────
      if (datos.esBeneficiario &&
          titularExistente == null &&
          datos.matriculaTitular != null &&
          datos.matriculaTitular!.isNotEmpty) {
        final paternoTit = datos.apellidoPaternoTitular ?? '';
        final nomTit = datos.nombresTitular ?? '';
        final fnTit = datos.fechaNacimientoTitular ?? DateTime.utc(1970);
        final sexoTit = datos.sexoTitular ?? 'masculino';

        if (paternoTit.isNotEmpty && nomTit.isNotEmpty) {
          await pacientesRepo.crearPaciente(
            CrearPacienteParams(
              nombres: nomTit,
              apellidoPaterno: paternoTit,
              apellidoMaterno: datos.apellidoMaternoTitular,
              fechaNacimiento: fnTit,
              sexo: sexoTit,
              empresaAseguradora: datos.empresaTitular,
            ),
          );
        }
      }

      // ── Paso 2: Si el paciente no existe, crearlo ─────────────────────────
      var pacienteFinal = pacienteExistente;
      if (pacienteFinal == null) {
        final resPaciente = await pacientesRepo.crearPaciente(
          CrearPacienteParams(
            nombres: datos.nombres,
            apellidoPaterno: datos.apellidoPaterno,
            apellidoMaterno: datos.apellidoMaterno,
            fechaNacimiento: datos.fechaNacimiento ?? DateTime.utc(1970),
            sexo: datos.sexo,
            tipoPaciente: datos.tipoPaciente,
            documentoNumero: datos.carnetIdentidad,
            empresaAseguradora: datos.empresaAseguradora,
            regional: datos.regional,
            edadAprox: datos.edadAprox,
          ),
        );

        if (resPaciente.esFallo) {
          state = state.copyWith(
            cargando: false,
            error:
                'Error al registrar paciente: ${resPaciente.fallaONula?.mensaje}',
          );
          return false;
        }
        pacienteFinal = resPaciente.valorONulo;
      }

      if (pacienteFinal == null) {
        state = state.copyWith(
          cargando: false,
          error: 'No se pudo obtener el identificador del paciente.',
        );
        return false;
      }

      // ── Paso 3: Registrar la internación hospitalaria ─────────────────────
      final resIngreso = await internacionesRepo.registrarIngreso(
        RegistrarIngresoParams(
          pacienteId: pacienteFinal.id,
          camaId: camaId,
          especialidadId: especialidadId,
          viaIngreso: datos.tipoIngreso,
          hospitalizadoPor: datos.hospitalizadoPor,
          responsablePago: datos.responsablePago,
          medicoTratante: datos.medicoTratante ?? 'MÉDICO DE TURNO',
          diagnosticoInicial:
              datos.diagnosticoInicial ?? 'INGRESO HOSPITALARIO',
          familiarReferenciaNombre: datos.contactoEmergenciaNombre,
          familiarReferenciaTelefono: datos.contactoEmergenciaTelefono,
          familiarReferenciaDireccion: datos.contactoEmergenciaDireccion,
          solicitarHistoriaAmarilla: solicitarHistoriaAmarilla,
        ),
      );

      if (resIngreso.esFallo) {
        state = state.copyWith(
          cargando: false,
          error:
              'Error al registrar ingreso: ${resIngreso.fallaONula?.mensaje}',
        );
        return false;
      }

      // Refrescar el tablero de camas globalmente
      ref.invalidate(tableroCamasProvider);

      state = state.copyWith(
        cargando: false,
        exito: true,
        mensaje: 'Ingreso hospitalario registrado exitosamente',
        resultado: resIngreso.valorONulo,
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        cargando: false,
        error: 'Ocurrió un error inesperado al procesar el ingreso: $e',
      );
      return false;
    }
  }
}

final AutoDisposeNotifierProvider<RegistroIngresoHC2Notifier,
        EstadoRegistroIngreso> registroIngresoHC2Provider =
    NotifierProvider.autoDispose<RegistroIngresoHC2Notifier,
        EstadoRegistroIngreso>(
  RegistroIngresoHC2Notifier.new,
);
