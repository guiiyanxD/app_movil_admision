import 'package:app_movil/features/censo_diario/domain/entities/censo_servicio.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/fecha_censo.dart';

/// Qué tan grave es una validación.
enum SeveridadValidacion {
  /// Impide guardar. Se reserva para lo que el backend rechazaría igual.
  bloqueante,

  /// No impide guardar. El operador tiene el papel delante y decide.
  advertencia,

  /// Contexto útil. Ni siquiera sugiere que haya un problema.
  informativa,
}

class ValidacionCenso {
  const ValidacionCenso({
    required this.id,
    required this.severidad,
    required this.mensaje,
    this.campo,
  });

  /// Identificador de SPEC-002 §7, para poder rastrear la regla al leer la UI.
  final String id;
  final SeveridadValidacion severidad;
  final String mensaje;

  /// Campo a resaltar, cuando la regla apunta a uno solo.
  final CampoCenso? campo;

  bool get esBloqueante => severidad == SeveridadValidacion.bloqueante;

  @override
  String toString() => '$id (${severidad.name}): $mensaje';
}

/// Valida un censo antes de enviarlo. Función pura, sin I/O.
///
/// El backend sigue siendo la única fuente de verdad: esto existe para dar
/// feedback inmediato y evitar un viaje de red que ya sabemos que fallaría.
class ValidarCensoServicio {
  const ValidarCensoServicio();

  List<ValidacionCenso> ejecutar({
    required CensoServicio censo,
    int? capacidad,
    int? totalDiaAnterior,
    bool servicioTieneMapeo = true,
    DateTime? ahora,
  }) {
    return [
      ..._contadoresNoNegativos(censo),
      ..._camasPrestadas(censo),
      ..._fecha(censo, ahora),
      ..._cuadre(censo, capacidad),
      ..._mapeo(servicioTieneMapeo),
      ..._saldo(censo, totalDiaAnterior),
    ];
  }

  // V-01
  Iterable<ValidacionCenso> _contadoresNoNegativos(CensoServicio censo) sync* {
    for (final campo in CampoCenso.values) {
      if (censo.valorDe(campo) < 0) {
        yield ValidacionCenso(
          id: 'V-01',
          severidad: SeveridadValidacion.bloqueante,
          campo: campo,
          mensaje: '${campo.etiqueta}: el valor no puede ser negativo.',
        );
      }
    }
  }

  // V-02 y V-04
  Iterable<ValidacionCenso> _camasPrestadas(CensoServicio censo) sync* {
    for (final cama in censo.camasPrestadas) {
      if (cama.cantidad < 1) {
        yield const ValidacionCenso(
          id: 'V-02',
          severidad: SeveridadValidacion.bloqueante,
          mensaje: 'La cantidad de una cama prestada debe ser al menos 1.',
        );
      }
    }

    if (censo.clavesDuplicadasCamasPrestadas().isNotEmpty) {
      yield const ValidacionCenso(
        id: 'V-04',
        severidad: SeveridadValidacion.bloqueante,
        mensaje: 'Hay una especialidad repetida con el mismo tipo de ingreso. '
            'Cada combinación puede aparecer una sola vez.',
      );
    }

    // V-10. Una cama prestada DIRECTO siempre corresponde a un ingreso por
    // admisión. No existe la comprobación equivalente para TRASLADO: ese tipo
    // incluye movimientos internos dentro del mismo servicio, que no son
    // ingresos por traslado, y compararlos daría falsos positivos.
    if (censo.camasPrestadasDirectas > censo.ingreso) {
      yield ValidacionCenso(
        id: 'V-10',
        severidad: SeveridadValidacion.informativa,
        campo: CampoCenso.ingreso,
        mensaje: 'Registraste ${censo.camasPrestadasDirectas} camas prestadas '
            'por ingreso directo, pero hay ${censo.ingreso} ingresos por '
            'admisión.',
      );
    }
  }

  // V-03
  Iterable<ValidacionCenso> _fecha(CensoServicio censo, DateTime? ahora) sync* {
    if (!FechaCenso.esCargable(censo.fecha, ahora: ahora)) {
      yield const ValidacionCenso(
        id: 'V-03',
        severidad: SeveridadValidacion.bloqueante,
        mensaje: 'Solo se pueden cargar fechas anteriores a hoy.',
      );
    }
  }

  // V-05
  Iterable<ValidacionCenso> _cuadre(CensoServicio censo, int? capacidad) sync* {
    if (capacidad == null) {
      // No se pudo consultar la capacidad. Degrada a advertencia y se deja que
      // el backend rechace: bloquear al operador por una falla de red en una
      // consulta auxiliar sería castigarlo por algo que no controla.
      yield const ValidacionCenso(
        id: 'V-05',
        severidad: SeveridadValidacion.advertencia,
        mensaje: 'No se pudo obtener la capacidad del servicio, así que el '
            'cuadre no se verificó. Podés guardar igual.',
      );
      return;
    }

    if (!censo.cuadraCon(capacidad)) {
      final suma = censo.sumaEstadosCama;
      final diferencia = suma - capacidad;
      final direccion = diferencia > 0 ? 'sobran' : 'faltan';

      yield ValidacionCenso(
        id: 'V-05',
        severidad: SeveridadValidacion.bloqueante,
        mensaje: 'El censo no cuadra: saldo + libres + bloqueadas + '
            'aislamiento da $suma y la capacidad del servicio es $capacidad. '
            'Te $direccion ${diferencia.abs()} camas.',
      );
    }
  }

  // V-06
  Iterable<ValidacionCenso> _mapeo(bool tieneMapeo) sync* {
    if (!tieneMapeo) {
      yield const ValidacionCenso(
        id: 'V-06',
        severidad: SeveridadValidacion.advertencia,
        mensaje: 'Este servicio todavía no tiene mapeo. Se puede guardar, pero '
            'el día no podrá confirmarse hasta que el equipo de datos lo '
            'complete.',
      );
    }
  }

  // V-07 y V-08
  Iterable<ValidacionCenso> _saldo(
    CensoServicio censo,
    int? totalDiaAnterior,
  ) sync* {
    if (totalDiaAnterior == null) {
      yield const ValidacionCenso(
        id: 'V-08',
        severidad: SeveridadValidacion.informativa,
        mensaje: 'No hay cierre del día anterior para este servicio, así que '
            'no se puede contrastar el saldo.',
      );
      return;
    }

    final esperado = censo.saldoEsperado(totalDiaAnterior);
    if (esperado != censo.total) {
      // Nunca bloquea. Durante el backfill es esperable que falten días
      // previos o que el papel tenga inconsistencias propias; el operador
      // tiene el documento delante y decide.
      yield ValidacionCenso(
        id: 'V-07',
        severidad: SeveridadValidacion.advertencia,
        campo: CampoCenso.total,
        mensaje: 'El saldo esperado es $esperado '
            '($totalDiaAnterior del día anterior + ${censo.totalIngresos} '
            'ingresos − ${censo.totalEgresos} egresos), pero cargaste '
            '${censo.total}. Verificá los movimientos.',
      );
    }
  }
}

extension ValidacionesCenso on List<ValidacionCenso> {
  bool get hayBloqueantes => any((v) => v.esBloqueante);

  List<ValidacionCenso> get bloqueantes =>
      where((v) => v.esBloqueante).toList();

  List<ValidacionCenso> deSeveridad(SeveridadValidacion s) =>
      where((v) => v.severidad == s).toList();

  ValidacionCenso? primeraDe(String id) {
    for (final v in this) {
      if (v.id == id) return v;
    }
    return null;
  }
}
