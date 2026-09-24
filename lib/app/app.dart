import 'package:app_movil/app/rutas.dart';
import 'package:app_movil/app/tema.dart';
import 'package:app_movil/app/widgets/navegacion_principal_scaffold.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:app_movil/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// El widget raíz. Se separó de main.dart para que ese archivo quede en una
/// línea y la composición viva entera en ootstrap.dart.
class AppMovil extends StatelessWidget {
  const AppMovil({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admisión — Caja Petrolera de Salud',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.claro(),
      darkTheme: TemaApp.oscuro(),
      // Los saltos entre features pasan por acá. Ver Rutas.
      onGenerateRoute: Rutas.generar,
      home: const PuertaDeSesion(),
    );
  }
}

/// Decide qué se muestra según el estado de la sesión.
///
/// Al abrir la app se lee el almacenamiento cifrado: si hay una sesión
/// guardada, el operador entra directo. Un turno de noche no debería empezar
/// tipeando credenciales.
class PuertaDeSesion extends ConsumerWidget {
  const PuertaDeSesion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sesionProvider);

    return switch (estado) {
      SesionCargando() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      SinSesion() => const LoginPage(),
      ConSesion() => const NavegacionPrincipalScaffold(),
    };
  }
}
