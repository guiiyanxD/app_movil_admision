import 'package:app_movil/features/reporteria/domain/entities/fila_reporte_censo.dart';
import 'package:app_movil/features/reporteria/domain/entities/movimiento_reporte.dart';

/// Una fila de la matriz: un período con su valor en cada servicio.
class FilaMatriz {
  const FilaMatriz({
    required this.periodo,
    required this.valores,
    required this.total,
  });

  final String periodo;

  /// Un valor por servicio, en el mismo orden que [MatrizReporte.servicios].
  final List<int> valores;

  /// Suma de [valores]. Es la columna "Total" de la derecha.
  final int total;
}

/// El reporte de un movimiento, listo para pintar en pantalla o en el PDF.
class MatrizReporte {
  const MatrizReporte({
    required this.movimiento,
    required this.servicios,
    required this.filas,
    required this.totalesPorServicio,
    required this.totalGeneral,
  });

  final MovimientoReporte movimiento;

  /// Nombres de servicio en el orden de las columnas.
  final List<String> servicios;

  final List<FilaMatriz> filas;

  /// Suma de cada columna. Es la fila TOTAL del pie.
  final List<int> totalesPorServicio;

  final int totalGeneral;

  bool get estaVacia => filas.isEmpty;
}

/// Convierte las filas planas del API en la matriz período × servicio.
///
/// Función pura. Vive en `domain/` y no en el generador de PDF **a propósito**:
/// la misma aritmética alimenta la tabla en pantalla y el impreso. Si cada uno
/// sumara por su cuenta, podrían discrepar, y una diferencia entre el total que
/// se ve y el que se imprime es de las cosas que nadie detecta hasta que
/// alguien lo suma a mano (SPEC-004, D-5).
class ArmarMatrizReporte {
  const ArmarMatrizReporte();

  /// [ordenConocido] son los nombres de servicio —en nomenclatura de vaciado—
  /// ordenados según el catálogo. Los que no estén ahí van al final.
  MatrizReporte ejecutar({
    required List<FilaReporteCenso> filas,
    required MovimientoReporte movimiento,
    List<String> ordenConocido = const [],
  }) {
    final servicios = ordenarServicios(
      filas.map((f) => f.servicio),
      ordenConocido,
    );
    final periodos = filas.map((f) => f.periodo).toSet().toList()..sort();

    // Índice por (periodo, servicio) para no recorrer la lista entera por cada
    // celda: con un mes de detalle diario y doce servicios son 372 celdas.
    final porClave = <String, FilaReporteCenso>{
      for (final f in filas) '${f.periodo}|${f.servicio}': f,
    };

    final filasMatriz = <FilaMatriz>[];
    final totalesPorServicio = List<int>.filled(servicios.length, 0);

    for (final periodo in periodos) {
      final valores = <int>[];

      for (var i = 0; i < servicios.length; i++) {
        // Un servicio sin fila en ese período no cargó nada ese día: es un cero
        // legítimo, no un dato faltante.
        final fila = porClave['$periodo|${servicios[i]}'];
        final valor = fila?.valorDe(movimiento) ?? 0;

        valores.add(valor);
        totalesPorServicio[i] += valor;
      }

      filasMatriz.add(
        FilaMatriz(
          periodo: periodo,
          valores: valores,
          total: valores.fold(0, (suma, v) => suma + v),
        ),
      );
    }

    return MatrizReporte(
      movimiento: movimiento,
      servicios: servicios,
      filas: filasMatriz,
      totalesPorServicio: totalesPorServicio,
      totalGeneral: totalesPorServicio.fold(0, (suma, v) => suma + v),
    );
  }

  /// Los ocho movimientos, calculados de una sola vez sobre las mismas filas.
  ///
  /// La pantalla toma uno y el PDF los toma todos, **del mismo cálculo**: es lo
  /// que hace que el número que se ve y el que se imprime no puedan discrepar
  /// (D-5), y que el PDF salga completo aunque en pantalla se esté mirando un
  /// solo movimiento (D-3, CA-08).
  List<MatrizReporte> todos({
    required List<FilaReporteCenso> filas,
    List<String> ordenConocido = const [],
  }) =>
      [
        for (final movimiento in MovimientoReporte.values)
          ejecutar(
            filas: filas,
            movimiento: movimiento,
            ordenConocido: ordenConocido,
          ),
      ];

  /// Ordena los servicios presentes según [ordenConocido], y deja al final los
  /// que no figuran ahí, alfabéticamente.
  ///
  /// El orden lo decide Admisión mediante `Servicio.indice`, y llega acá ya
  /// resuelto. **Nunca se ordena alfabéticamente el conjunto entero**: eso
  /// rompería la correspondencia con el reporte de la web y con la pila de
  /// formularios de papel.
  ///
  /// Un servicio que aparece en los datos pero no en el catálogo —renombrado,
  /// sin mapeo, dado de baja— **no se descarta**. Ocultarlo sería perder filas
  /// del reporte por un problema de catálogo, en silencio.
  static List<String> ordenarServicios(
    Iterable<String> presentes,
    List<String> ordenConocido,
  ) {
    final restantes = presentes.toSet();
    final ordenados = <String>[];

    for (final nombre in ordenConocido) {
      if (restantes.remove(nombre)) ordenados.add(nombre);
    }

    final huerfanos = restantes.toList()..sort();
    return [...ordenados, ...huerfanos];
  }
}
