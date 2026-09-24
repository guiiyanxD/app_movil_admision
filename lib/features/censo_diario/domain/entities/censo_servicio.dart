import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';

/// Consolidado estadístico de UN servicio en UNA fecha. Núcleo del EST-1.
///
/// Dart puro: no conoce Flutter, HTTP ni JSON. Todas las reglas de negocio del
/// censo viven acá y se testean sin levantar nada.
class CensoServicio {
  const CensoServicio({
    required this.fecha,
    required this.servicioId,
    this.ingreso = 0,
    this.ingresoTraslado = 0,
    this.egreso = 0,
    this.egresoTraslado = 0,
    this.obito = 0,
    this.aislamiento = 0,
    this.bloqueada = 0,
    this.libre = 0,
    this.total = 0,
    this.camasPrestadas = const [],
  });

  final DateTime fecha;
  final String servicioId;

  final int ingreso;
  final int ingresoTraslado;
  final int egreso;
  final int egresoTraslado;
  final int obito;

  final int aislamiento;
  final int bloqueada;
  final int libre;

  /// "Saldo pacientes a las 24 horas" del formulario.
  final int total;

  final List<CamaPrestada> camasPrestadas;

  // ── Lectura por campo ──────────────────────────────────────────────────

  int valorDe(CampoCenso campo) => switch (campo) {
        CampoCenso.ingreso => ingreso,
        CampoCenso.ingresoTraslado => ingresoTraslado,
        CampoCenso.egreso => egreso,
        CampoCenso.egresoTraslado => egresoTraslado,
        CampoCenso.obito => obito,
        CampoCenso.aislamiento => aislamiento,
        CampoCenso.bloqueada => bloqueada,
        CampoCenso.libre => libre,
        CampoCenso.total => total,
      };

  CensoServicio conCampo(CampoCenso campo, int valor) => switch (campo) {
        CampoCenso.ingreso => copyWith(ingreso: valor),
        CampoCenso.ingresoTraslado => copyWith(ingresoTraslado: valor),
        CampoCenso.egreso => copyWith(egreso: valor),
        CampoCenso.egresoTraslado => copyWith(egresoTraslado: valor),
        CampoCenso.obito => copyWith(obito: valor),
        CampoCenso.aislamiento => copyWith(aislamiento: valor),
        CampoCenso.bloqueada => copyWith(bloqueada: valor),
        CampoCenso.libre => copyWith(libre: valor),
        CampoCenso.total => copyWith(total: valor),
      };

  // ── Reglas de negocio derivadas ────────────────────────────────────────

  /// Dotación. **No se envía al backend**: el servidor la recalcula como
  /// `total + libre` y descarta cualquier valor que se mande. Se muestra en
  /// pantalla como campo calculado de solo lectura.
  int get dotacion => total + libre;

  int get totalIngresos => ingreso + ingresoTraslado;

  /// Incluye los óbitos, que restan del saldo de forma independiente del
  /// egreso: un fallecido no se cuenta además como egreso (ADR-0005, D-4).
  int get totalEgresos => egreso + egresoTraslado + obito;

  /// Suma de todos los estados de cama. Debe igualar la capacidad del servicio.
  int get sumaEstadosCama => total + libre + bloqueada + aislamiento;

  /// Cuadre contra la capacidad real (cantidad de camas activas del servicio).
  ///
  /// Idéntica a `calcularCuadreCargaManual` del backend. Se prevalida en el
  /// cliente con la capacidad de `GET /camas` para evitar el 400.
  bool cuadraCon(int capacidad) => sumaEstadosCama == capacidad;

  /// Camas libres que se deducen de la capacidad del servicio.
  ///
  /// Es la regla de cuadre del backend, despejada:
  /// ```
  ///   total + libre + bloqueada + aislamiento == capacidad
  /// → libre = capacidad − total − bloqueada − aislamiento
  /// ```
  ///
  /// **Se ofrece como sugerencia, nunca se impone.** El valor de [libre] viene
  /// transcrito del formulario de papel, y compararlo contra este cálculo es el
  /// único control cruzado que existe sobre los otros cuatro números: si el
  /// operador tipea mal el saldo, el desacuerdo lo delata. Calcular el campo en
  /// vez de contrastarlo haría que la ecuación cuadre siempre por construcción
  /// y el error entraría al histórico sin que nadie lo note.
  ///
  /// Hay una razón más, propia del backfill: la capacidad sale del catálogo de
  /// camas **de hoy**, no del de la fecha que se está cargando. Usarla para
  /// validar y avisar es razonable; usarla para generar un dato que se persiste
  /// como hecho histórico sería inventar una cifra que nunca fue cierta.
  ///
  /// Puede dar negativo: eso significa que los otros valores no entran en la
  /// capacidad, no que haya camas libres negativas.
  int? camasLibresSegunCapacidad(int? capacidad) {
    if (capacidad == null) return null;
    return capacidad - total - bloqueada - aislamiento;
  }

  /// Saldo esperado a las 24 h a partir del cierre del día anterior.
  ///
  /// Verificado contra el EST-1 del 16 de julio (Medicina Interna, piso 1°):
  /// `33 + 4 − 3 − 0 = 34`.
  int saldoEsperado(int totalDiaAnterior) =>
      totalDiaAnterior + totalIngresos - totalEgresos;

  /// Aplica el signo de cada tipo de movimiento. Equivale a
  /// [saldoEsperado], expresado sobre la enumeración de movimientos.
  int saldoEsperadoPorMovimiento(int totalDiaAnterior) {
    var saldo = totalDiaAnterior;
    for (final movimiento in TipoMovimientoCenso.values) {
      saldo += movimiento.signoEnSaldo * valorDe(movimiento.campo);
    }
    return saldo;
  }

  /// Camas prestadas registradas con ingreso directo.
  ///
  /// Se contrasta contra [ingreso] en la validación informativa V-10. No existe
  /// equivalente para `TRASLADO`: ese tipo incluye movimientos internos dentro
  /// del mismo servicio, que no son ingresos por traslado del servicio, y la
  /// comparación daría falsos positivos.
  int get camasPrestadasDirectas => camasPrestadas
      .where((c) => c.tipoIngreso == TipoIngresoCamaPrestada.directo)
      .fold(0, (suma, c) => suma + c.cantidad);

  /// `true` si los 9 contadores y las camas prestadas coinciden.
  ///
  /// Compara valores, no identidad: sirve para saber si lo que hay en pantalla
  /// difiere de lo último que se persistió.
  bool mismosValoresQue(CensoServicio? otro) {
    if (otro == null) return false;

    for (final campo in CampoCenso.values) {
      if (valorDe(campo) != otro.valorDe(campo)) return false;
    }

    if (camasPrestadas.length != otro.camasPrestadas.length) return false;
    for (var i = 0; i < camasPrestadas.length; i++) {
      if (camasPrestadas[i] != otro.camasPrestadas[i]) return false;
    }

    return true;
  }

  /// `true` si no se cargó nada todavía.
  bool get estaVacio =>
      CampoCenso.values.every((c) => valorDe(c) == 0) && camasPrestadas.isEmpty;

  /// Combinaciones especialidad + tipo ya registradas.
  ///
  /// El selector las excluye para que el operador no pueda armar el duplicado
  /// que el backend rechazaría: es preferible que el estado inválido no se
  /// pueda construir a explicarlo después con un error.
  Set<String> get clavesCamasPrestadasUsadas =>
      {for (final cama in camasPrestadas) cama.claveUnicidad};

  /// Combinaciones especialidad + tipo repetidas, que el backend rechaza.
  List<String> clavesDuplicadasCamasPrestadas() {
    final vistas = <String>{};
    final duplicadas = <String>[];
    for (final cama in camasPrestadas) {
      if (!vistas.add(cama.claveUnicidad)) {
        duplicadas.add(cama.claveUnicidad);
      }
    }
    return duplicadas;
  }

  CensoServicio copyWith({
    DateTime? fecha,
    String? servicioId,
    int? ingreso,
    int? ingresoTraslado,
    int? egreso,
    int? egresoTraslado,
    int? obito,
    int? aislamiento,
    int? bloqueada,
    int? libre,
    int? total,
    List<CamaPrestada>? camasPrestadas,
  }) {
    return CensoServicio(
      fecha: fecha ?? this.fecha,
      servicioId: servicioId ?? this.servicioId,
      ingreso: ingreso ?? this.ingreso,
      ingresoTraslado: ingresoTraslado ?? this.ingresoTraslado,
      egreso: egreso ?? this.egreso,
      egresoTraslado: egresoTraslado ?? this.egresoTraslado,
      obito: obito ?? this.obito,
      aislamiento: aislamiento ?? this.aislamiento,
      bloqueada: bloqueada ?? this.bloqueada,
      libre: libre ?? this.libre,
      total: total ?? this.total,
      camasPrestadas: camasPrestadas ?? this.camasPrestadas,
    );
  }
}
