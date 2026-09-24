import 'package:app_movil/app/widgets/pantalla_cuenta_perfil.dart';
import 'package:app_movil/features/censo_diario/presentation/pages/seleccion_fecha_page.dart';
import 'package:app_movil/features/dashboard/presentation/dashboard_page.dart';
import 'package:app_movil/features/reporteria/presentation/pages/reporte_censo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Contenedor raíz con barra de navegación inferior (NavigationBar M3).
///
/// Permite cambiar al instante entre las áreas del sistema sin perder
/// estado ni scroll: Inicio (Dashboard), Censo Diario, Reportes y Perfil/Ajustes.
class NavegacionPrincipalScaffold extends StatefulWidget {
  const NavegacionPrincipalScaffold({super.key});

  @override
  State<NavegacionPrincipalScaffold> createState() =>
      _NavegacionPrincipalScaffoldState();
}

class _NavegacionPrincipalScaffoldState
    extends State<NavegacionPrincipalScaffold> {
  int _indiceActual = 0;

  void _irA(int indice) {
    if (_indiceActual == indice) return;
    HapticFeedback.selectionClick();
    setState(() => _indiceActual = indice);
  }

  late final List<Widget> _pantallas = [
    DashboardPage(
      onNavegarACenso: () => _irA(1),
      onNavegarAReportes: () => _irA(2),
    ),
    const SeleccionFechaPage(),
    const ReporteCensoPage(),
    const PantallaCuentaPerfil(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceActual,
        children: _pantallas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: _irA,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Censo',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
