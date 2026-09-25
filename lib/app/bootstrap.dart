import 'package:app_movil/app/app.dart';
import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/core/config/gestor_servidor.dart';
import 'package:app_movil/core/red/api_client.dart';
import 'package:app_movil/core/red/red_providers.dart';
import 'package:app_movil/core/sesion/permisos_providers.dart';
import 'package:app_movil/features/auth/data/almacen_sesion_seguro.dart';
import 'package:app_movil/features/auth/data/auth_remote_datasource.dart';
import 'package:app_movil/features/auth/data/proveedor_de_sesion_auth.dart';
import 'package:app_movil/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:app_movil/features/auth/data/sesion_en_memoria.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:app_movil/features/censo_diario/data/datasources/censo_diario_remote_datasource.dart';
import 'package:app_movil/features/censo_diario/data/repositories/censo_diario_repository_impl.dart';
import 'package:app_movil/features/censo_diario/presentation/providers/censo_providers.dart';
import 'package:app_movil/features/historiales_clinicos/data/datasources/historiales_remote_datasource.dart';
import 'package:app_movil/features/historiales_clinicos/data/repositories/historiales_repository_impl.dart';
import 'package:app_movil/features/historiales_clinicos/presentation/providers/historiales_providers.dart';
import 'package:app_movil/features/internaciones/data/datasources/camas_remote_datasource.dart';
import 'package:app_movil/features/internaciones/data/datasources/internaciones_remote_datasource.dart';
import 'package:app_movil/features/internaciones/data/datasources/pacientes_remote_datasource.dart';
import 'package:app_movil/features/internaciones/data/repositories/camas_repository_impl.dart';
import 'package:app_movil/features/internaciones/data/repositories/internaciones_repository_impl.dart';
import 'package:app_movil/features/internaciones/data/repositories/pacientes_repository_impl.dart';
import 'package:app_movil/features/internaciones/presentation/providers/ingreso_hc2_providers.dart';
import 'package:app_movil/features/internaciones/presentation/providers/tablero_camas_providers.dart';
import 'package:app_movil/features/reporteria/data/datasources/reporteria_remote_datasource.dart';
import 'package:app_movil/features/reporteria/data/repositories/reporteria_repository_impl.dart';
import 'package:app_movil/features/reporteria/presentation/providers/reporteria_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Raíz de composición: el **único** lugar donde se deciden las dependencias.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  runApp(
    ProviderScope(
      overrides: _dependencias(),
      child: const AppMovil(),
    ),
  );
}

List<Override> _dependencias() {
  final memoria = SesionEnMemoria();
  final almacen = AlmacenSesionSeguro();

  return [
    configuracionProvider.overrideWith(
      (ref) => ref.watch(gestorServidorProvider).config,
    ),

    // El repositorio de autenticación reacciona a cambios en configuracionProvider:
    authRepositoryProvider.overrideWith((ref) {
      final config = ref.watch(configuracionProvider);
      return AuthRepositoryImpl(
        remoto: AuthRemoteDataSource(ApiClient.crear(config)),
        almacen: almacen,
        memoria: memoria,
      );
    }),

    // `core/red/` declara que necesita una sesión; `auth` la satisface.
    proveedorDeSesionProvider.overrideWith(
      (ref) => ProveedorDeSesionAuth(
        repositorio: ref.watch(authRepositoryProvider),
        memoria: memoria,
        alPerder: () => ref.read(sesionProvider.notifier).marcarSesionPerdida(),
      ),
    ),

    censoRepositoryProvider.overrideWith(
      (ref) => CensoDiarioRepositoryImpl(
        CensoDiarioRemoteDataSource(ref.watch(dioProvider)),
      ),
    ),

    reporteriaRepositoryProvider.overrideWith(
      (ref) => ReporteriaRepositoryImpl(
        ReporteriaRemoteDataSource(ref.watch(dioProvider)),
      ),
    ),

    camasRepositoryProvider.overrideWith(
      (ref) => CamasRepositoryImpl(
        CamasRemoteDataSource(ref.watch(dioProvider)),
      ),
    ),

    pacientesRepositoryProvider.overrideWith(
      (ref) => PacientesRepositoryImpl(
        PacientesRemoteDataSource(ref.watch(dioProvider)),
      ),
    ),

    internacionesRepositoryProvider.overrideWith(
      (ref) => InternacionesRepositoryImpl(
        InternacionesRemoteDataSource(ref.watch(dioProvider)),
      ),
    ),

    historialesRepositoryProvider.overrideWith(
      (ref) => HistorialesRepositoryImpl(
        HistorialesRemoteDataSource(ref.watch(dioProvider)),
      ),
    ),

    puedeEscribirProvider.overrideWith(
      (ref) => ref.watch(sesionActivaProvider)?.puedeEscribir ?? false,
    ),

    ordenServiciosProvider.overrideWith((ref) async {
      try {
        final servicios = await ref.watch(serviciosProvider.future);
        return [
          for (final servicio in servicios)
            if (servicio.tieneMapeo) servicio.nombreVaciado!,
        ];
      } on Object {
        return const <String>[];
      }
    }),
  ];
}
