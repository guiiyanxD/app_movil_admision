import 'package:app_movil/core/error/failure.dart';
import 'package:app_movil/core/error/resultado.dart';
import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/progreso_dia.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/domain/repositories/censo_diario_repository.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_controller.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:app_movil/features/censo_diario/presentation/state/fase_formulario.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioFalso implements CensoDiarioRepository {
  Failure? fallaAlGuardar;
  final List<CensoServicio> guardados = [];

  @override
  Future<Resultado<int>> obtenerCapacidadServicio(String servicioId) async =>
      const Exito(38);

  @override
  Future<Resultado<int?>> obtenerTotalDiaAnterior({
    required DateTime fecha,
    required String nombreVaciado,
  }) async =>
      const Exito(33);

  @override
  Future<Resultado<List<CargaGuardada>>> obtenerCargasDelDia(
    DateTime fecha, {
    String? servicioId,
  }) async =>
      const Exito([]);

  @override
  Future<Resultado<CensoServicio>> guardarCensoServicio(
    CensoServicio censo,
  ) async {
    final falla = fallaAlGuardar;
    if (falla != null) return Fallo(falla);
    guardados.add(censo);
    return Exito(censo);
  }

  @override
  Future<Resultado<List<Servicio>>> obtenerServiciosActivos() async =>
      const Exito([]);

  @override
  Future<Resultado<List<MapeoVaciado>>> obtenerMapeoEspecialidades() async =>
      const Exito([]);

  @override
  Future<Resultado<CierreCenso?>> obtenerCierre(DateTime fecha) async =>
      const Exito(null);

  @override
  Future<Resultado<ProgresoDia>> obtenerProgresoDia(DateTime fecha) async =>
      Exito(ProgresoDia(fecha: fecha, servicios: const []));

  @override
  Future<Resultado<ConfirmacionDia>> confirmarDia(DateTime fecha) async =>
      const Exito(ConfirmacionDia(fecha: '2026-07-16', servicios: 0));
}

void main() {
  final ahora = DateTime.utc(2026, 7, 31, 14);
  final fecha = DateTime(2026, 7, 16);

  const servicio = Servicio(
    id: 'srv-1',
    nombre: 'Medicina Interna',
    activo: true,
    nombreVaciado: 'Medicina Interna',
  );

  late _RepositorioFalso repositorio;
  late CensoFormLogica logica;

  setUp(() {
    repositorio = _RepositorioFalso();
    logica = CensoFormLogica(
      repositorio: repositorio,
      estadoInicial: CensoFormState.inicial(servicio: servicio, fecha: fecha),
      ahora: ahora,
    );
  });

  Future<void> llenarCensoValido() async {
    await logica.cargarReferencias();
    logica
      ..cambiarCampo(CampoCenso.ingreso, 4)
      ..cambiarCampo(CampoCenso.egreso, 3)
      ..cambiarCampo(CampoCenso.total, 34)
      ..cambiarCampo(CampoCenso.libre, 2)
      ..cambiarCampo(CampoCenso.bloqueada, 1)
      ..cambiarCampo(CampoCenso.aislamiento, 1);
  }

  group('Detección de cambios sin guardar', () {
    test('un formulario recién abierto no tiene cambios', () async {
      await logica.cargarReferencias();

      // Navegar sin tocar nada no debe preguntar nada.
      expect(logica.estado.hayCambiosSinGuardar, isFalse);
    });

    test('tocar un campo marca cambios pendientes', () async {
      await logica.cargarReferencias();
      logica.cambiarCampo(CampoCenso.ingreso, 4);

      expect(logica.estado.hayCambiosSinGuardar, isTrue);
    });

    test('guardar limpia la marca', () async {
      await llenarCensoValido();
      await logica.guardar();

      expect(logica.estado.hayCambiosSinGuardar, isFalse);
      expect(logica.estado.censoPersistido, isNotNull);
    });

    test('tras guardar se puede seguir corrigiendo sin salir de la pantalla',
        () async {
      await llenarCensoValido();
      await logica.guardar();

      // Con flechas de navegación el operador se queda acá. Si la fase
      // quedara en `guardado`, cambiarCampo lo ignoraría y el formulario
      // parecería congelado.
      expect(logica.estado.fase, FaseFormulario.edicion);

      logica.cambiarCampo(CampoCenso.obito, 2);
      expect(logica.estado.censo.obito, 2);
    });

    test('editar después de guardar vuelve a marcarla', () async {
      await llenarCensoValido();
      await logica.guardar();
      logica.cambiarCampo(CampoCenso.obito, 1);

      expect(logica.estado.hayCambiosSinGuardar, isTrue);
    });

    test('volver al valor guardado la limpia de nuevo', () async {
      await llenarCensoValido();
      await logica.guardar();
      logica
        ..cambiarCampo(CampoCenso.obito, 1)
        ..cambiarCampo(CampoCenso.obito, 0);

      expect(logica.estado.hayCambiosSinGuardar, isFalse);
    });

    test('un guardado fallido deja la marca puesta', () async {
      await llenarCensoValido();
      repositorio.fallaAlGuardar = const FallaRed();
      await logica.guardar();

      // Si la limpiara, navegar perdería el trabajo en silencio.
      expect(logica.estado.hayCambiosSinGuardar, isTrue);
      expect(logica.estado.censoPersistido, isNull);
    });

    test('cambiar las camas prestadas también cuenta como cambio', () async {
      await llenarCensoValido();
      await logica.guardar();
      logica
        ..reemplazarCamasPrestadas(const [
          CamaPrestada(
            especialidadId: 'esp-1',
            cantidad: 1,
            tipoIngreso: TipoIngresoCamaPrestada.directo,
          ),
        ]);

      expect(logica.estado.hayCambiosSinGuardar, isTrue);
    });
  });

  // El grupo "Aviso de sobrescritura" se retiró junto con
  // `sobrescribiriaCargaPrevia`: con la precarga andando el formulario muestra
  // los valores del servidor, así que no queda sobrescritura ciega que
  // advertir. Lo que la reemplaza —la procedencia— se cubre en
  // `procedencia_carga_test.dart` (SPEC-003, D-5).

  group('CensoServicio.mismosValoresQue', () {
    test('compara valores, no identidad', () {
      final a = CensoServicio(fecha: fecha, servicioId: 's', ingreso: 4);
      final b = CensoServicio(fecha: fecha, servicioId: 's', ingreso: 4);

      expect(a.mismosValoresQue(b), isTrue);
      expect(identical(a, b), isFalse);
    });

    test('detecta diferencia en cualquiera de los 9 campos', () {
      final base = CensoServicio(fecha: fecha, servicioId: 's');
      for (final campo in CampoCenso.values) {
        expect(
          base.mismosValoresQue(base.conCampo(campo, 1)),
          isFalse,
          reason: campo.name,
        );
      }
    });

    test('null nunca es igual', () {
      expect(
        CensoServicio(fecha: fecha, servicioId: 's').mismosValoresQue(null),
        isFalse,
      );
    });

    test('estaVacio distingue el formulario intacto', () {
      final vacio = CensoServicio(fecha: fecha, servicioId: 's');
      expect(vacio.estaVacio, isTrue);
      expect(vacio.conCampo(CampoCenso.libre, 1).estaVacio, isFalse);
    });
  });
}
