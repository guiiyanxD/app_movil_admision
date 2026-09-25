import 'package:app_movil/app/rutas.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry/sentry.dart';

/// Menú de cuenta del `AppBar`: quién sos, herramientas y cerrar sesión.
///
/// Vive en `app/` y no en una feature **a propósito**. Estaba dentro de la
/// pantalla de selección de fecha, que es del censo diario, y por eso esa
/// feature importaba la presentación de `auth` para leer el usuario y cerrar
/// sesión, y la de `diagnostico` para abrir sus herramientas (SPEC-005, H-8).
///
/// No es contenido de ninguna feature: es chrome de la aplicación, igual que el
/// tema o las rutas. `app/` puede conocer a todas; una feature no.
class MenuDeCuenta extends ConsumerWidget {
  const MenuDeCuenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final sesion = ref.watch(sesionActivaProvider);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: sesion?.usuario.nombreCompleto ?? 'Sesión',
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sesion?.usuario.nombreCompleto ?? ''),
              Text(sesion?.rol.etiqueta ?? '', style: tema.textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _salir,
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      onSelected: (valor) {
        if (valor == _salir) {
          ref.read(sesionProvider.notifier).cerrarSesion();
          return;
        }
        Navigator.of(context).pushNamed(valor);
      },
    );
  }

  /// No es una ruta: cerrar sesión no navega, cambia el estado y la
  /// `PuertaDeSesion` decide qué mostrar.
  static const String _salir = 'salir';
}
