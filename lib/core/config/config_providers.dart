import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuración activa. **La inyecta la raíz de composición.**
///
/// Lanza si nadie la sobreescribió para detectar tempranamente problemas
/// de cableado de dependencias (CA-03).
/// En ejecución normal, `bootstrap()` la sobreescribe dinámicamente con
/// `ref.watch(gestorServidorProvider).config`.
final configuracionProvider = Provider<ConfiguracionApp>((ref) {
  throw UnimplementedError(
    'configuracionProvider no fue sobreescrito.\n'
    'La configuración se inyecta en el ProviderScope de lib/app/bootstrap.dart. '
    'En un test, agregá el override al ProviderScope de la prueba.',
  );
});
