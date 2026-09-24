import 'package:app_movil/core/red/proveedor_de_sesion.dart';
import 'package:app_movil/features/auth/data/sesion_en_memoria.dart';
import 'package:app_movil/features/auth/domain/repositories/auth_repository.dart';

/// Adaptador: `auth` satisface el contrato que declara `core/red/`.
///
/// Toda la dirección de la dependencia vive en esta clase. El núcleo no
/// conoce `AuthRepository`; es esta feature la que se ofrece a cumplir lo que
/// el núcleo pidió (ADR-0006, D-3). Se cablea en `bootstrap()`.
class ProveedorDeSesionAuth implements ProveedorDeSesion {
  ProveedorDeSesionAuth({
    required AuthRepository repositorio,
    required SesionEnMemoria memoria,
    required void Function() alPerder,
  })  : _repositorio = repositorio,
        _memoria = memoria,
        _alPerder = alPerder;

  final AuthRepository _repositorio;
  final SesionEnMemoria _memoria;
  final void Function() _alPerder;

  /// Evita renovaciones en paralelo: si cinco peticiones reciben 401 a la vez,
  /// se dispara una sola y las demás esperan su resultado.
  ///
  /// Estaba dentro de `AuthRepository`, que ya cargaba con la red, la
  /// persistencia y el estado de la sesión (SPEC-005, H-5). Vive acá porque es
  /// **este** contrato el que promete la garantía —lo dice la documentación de
  /// `ProveedorDeSesion.refrescar`— y porque el interceptor es el único que
  /// dispara renovaciones concurrentes. Coordinar peticiones simultáneas es del
  /// que las emite, no de la operación que las atiende.
  Future<bool>? _enCurso;

  /// Se lee de la sesión en memoria, no del almacenamiento cifrado: pasa por
  /// acá cada petición y un viaje al Keystore por request sería caro.
  @override
  String? get accessToken => _memoria.accessToken;

  @override
  Future<bool> refrescar() {
    final enCurso = _enCurso;
    if (enCurso != null) return enCurso;

    final futuro = _repositorio.refrescar();
    _enCurso = futuro;

    return futuro.whenComplete(() => _enCurso = null);
  }

  @override
  void alPerderSesion() => _alPerder();
}
