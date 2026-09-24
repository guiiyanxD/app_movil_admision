import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';

/// Los 5 tipos de evento del EST-1.
///
/// En este módulo **no clasifican filas de paciente** — el detalle por paciente
/// no se digitaliza (ADR-0005, D-2). Etiquetan cada uno de los 5 contadores de
/// movimiento del consolidado.
enum TipoMovimientoCenso {
  ingresoDirecto(campo: CampoCenso.ingreso, signoEnSaldo: 1),
  ingresoPorTraslado(campo: CampoCenso.ingresoTraslado, signoEnSaldo: 1),
  egresoDirecto(campo: CampoCenso.egreso, signoEnSaldo: -1),
  egresoPorTraslado(campo: CampoCenso.egresoTraslado, signoEnSaldo: -1),
  obito(campo: CampoCenso.obito, signoEnSaldo: -1);

  const TipoMovimientoCenso({required this.campo, required this.signoEnSaldo});

  final CampoCenso campo;

  /// Signo con el que el contador afecta el saldo de las 24 horas.
  ///
  /// El óbito resta de forma independiente del egreso: un fallecido **no** se
  /// cuenta además como egreso (ADR-0005, D-4).
  final int signoEnSaldo;

  String get etiqueta => campo.etiqueta;

  bool get esIngreso => signoEnSaldo > 0;
}

/// Tipo de ingreso de una cama prestada.
///
/// Refleja la clasificación de la query canónica del backend
/// (`construirFilasCamasPrestadas`): `DIRECTO` cuando la estancia no tiene una
/// estancia previa contigua, `TRASLADO` cuando el paciente venía de otra cama.
enum TipoIngresoCamaPrestada {
  directo('DIRECTO', 'Ingreso directo'),
  traslado('TRASLADO', 'Por traslado');

  const TipoIngresoCamaPrestada(this.valorApi, this.etiqueta);

  /// Literal exacto que exige el backend. No admite variantes.
  final String valorApi;
  final String etiqueta;

  /// Lanza [FormatException] ante un literal desconocido.
  ///
  /// A diferencia de `OrigenCierre` y `RolUsuario`, que ante un valor nuevo
  /// caen en la opción más restrictiva, acá **no existe una opción segura**:
  /// `DIRECTO` y `TRASLADO` son clasificaciones equivalentes y elegir una al
  /// azar inventaría un dato del histórico hospitalario.
  ///
  /// Se lanza `FormatException` y no `StateError` a propósito: el repositorio
  /// ya la traduce a `FallaFormatoInesperado` —"el servidor cambió el
  /// contrato"—, mientras que un `StateError` se escaparía sin atrapar y
  /// rompería la degradación amable que promete CA-07.
  static TipoIngresoCamaPrestada desdeApi(String valor) => values.firstWhere(
        (t) => t.valorApi == valor,
        orElse: () => throw FormatException(
          'Tipo de ingreso de cama prestada desconocido: "$valor"',
        ),
      );
}
