import 'package:app_movil/features/diagnostico/presentation/pantalla_diagnostico_dictado.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/admision/pantalla_crear_lote_solicitud.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/admision/pantalla_dashboard_recepcion.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/archivo/pantalla_dashboard_archivo.dart';
import 'package:app_movil/features/internaciones/presentation/pages/tablero_camas_page.dart';
import 'package:app_movil/features/reporteria/presentation/pages/pantalla_prueba_pdf.dart';
import 'package:app_movil/features/reporteria/presentation/pages/reporte_censo_page.dart';
import 'package:flutter/material.dart';

/// Tabla de rutas entre features.
///
/// Antes cada pantalla importaba la clase de la pantalla destino para
/// construirla. Con eso, el menú del censo diario dependía de reportería y de
/// diagnóstico, el login dependía de diagnóstico, y aparecían tres ciclos que
/// hacían imposible compilar o probar una feature por separado (SPEC-005, H-8).
///
/// Acá el destino se nombra con una constante y `app/` es el único que conoce
/// las dos puntas. Una feature nueva se agrega en esta tabla, no en el menú.
///
/// **Solo viven acá los saltos entre features.** Navegar dentro de una —”del
/// checklist del día al formulario de un servicio—” sigue con `MaterialPageRoute`
/// directo: no cruza ningún límite y pasar por una tabla solo escondería el
/// argumento tipado detrás de un `Object?`.
abstract final class Rutas {
  static const String diagnosticoDictado = '/diagnostico/dictado';
  static const String pruebaPdf = '/diagnostico/pdf';
  static const String reporteCenso = '/reporteria/censo';
  static const String tableroCamas = '/internaciones/tablero';

  static const String solicitarHistoriales = '/historiales/solicitar';
  static const String recepcionHistoriales = '/historiales/recepcion';
  static const String dashboardArchivo = '/historiales/archivo/dashboard';

  /// Se conecta a `MaterialApp.onGenerateRoute`.
  ///
  /// Devuelve `null` ante un nombre desconocido, que es como `MaterialApp`
  /// espera que se le diga "esta ruta no es mía".
  static Route<void>? generar(RouteSettings ajustes) {
    final constructor = _destinos[ajustes.name];
    if (constructor == null) return null;

    return MaterialPageRoute<void>(builder: constructor, settings: ajustes);
  }

  static const Map<String, WidgetBuilder> _destinos = {
    diagnosticoDictado: _aDiagnostico,
    pruebaPdf: _aPruebaPdf,
    reporteCenso: _aReporteCenso,
    tableroCamas: _aTableroCamas,
    solicitarHistoriales: _aSolicitarHistoriales,
    recepcionHistoriales: _aRecepcionHistoriales,
    dashboardArchivo: _aDashboardArchivo,
  };

  static Widget _aDiagnostico(BuildContext _) =>
      const PantallaDiagnosticoDictado();

  static Widget _aPruebaPdf(BuildContext _) => const PantallaPruebaPdf();

  static Widget _aReporteCenso(BuildContext _) => const ReporteCensoPage();

  static Widget _aTableroCamas(BuildContext _) => const TableroCamasPage();

  static Widget _aSolicitarHistoriales(BuildContext _) =>
      const PantallaCrearLoteSolicitud();

  static Widget _aRecepcionHistoriales(BuildContext _) =>
      const PantallaDashboardRecepcion();

  static Widget _aDashboardArchivo(BuildContext _) =>
      const PantallaDashboardArchivo();
}
