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

    final internacionesRepo = ref.read(internacionesRepositoryProvider);

    try {
      // ── Mapeo de campos opcionales del titular (si aplica) ────────────────
      Map<String, dynamic>? datosTitular;
      if (datos.esBeneficiario &&
          titularExistente == null &&
          datos.matriculaTitular != null &&
          datos.matriculaTitular!.isNotEmpty &&
          datos.nombresTitular != null &&
          datos.apellidoPaternoTitular != null) {
        datosTitular = {
          'matricula': datos.matriculaTitular,
          'nombres': datos.nombresTitular,
          'apellidoPaterno': datos.apellidoPaternoTitular,
          'apellidoMaterno': datos.apellidoMaternoTitular,
        };
      }

      // ── Registro de la internación hospitalaria (Atómico) ─────────────────
      final resIngreso = await internacionesRepo.registrarIngreso(
        RegistrarIngresoParams(
          pacienteId: pacienteExistente?.id,
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
          
          // Datos para la creación del paciente al vuelo
          nombres: pacienteExistente == null ? datos.nombres : null,
          apellidoPaterno: pacienteExistente == null ? datos.apellidoPaterno : null,
          apellidoMaterno: pacienteExistente == null ? datos.apellidoMaterno : null,
          fechaNacimiento: pacienteExistente == null ? (datos.fechaNacimiento?.toIso8601String() ?? DateTime.utc(1970).toIso8601String()) : null,
          sexo: pacienteExistente == null ? datos.sexo : null,
          tipoPaciente: pacienteExistente == null ? datos.tipoPaciente : null,
          documentoNumero: pacienteExistente == null ? datos.carnetIdentidad : null,
          empresaAseguradora: pacienteExistente == null ? datos.empresaAseguradora : null,
          regional: pacienteExistente == null ? datos.regional : null,
          datosTitular: datosTitular,
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
