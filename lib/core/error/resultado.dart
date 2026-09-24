import 'package:app_movil/core/error/failure.dart';

/// Resultado de una operación que puede fallar.
///
/// Se usa clase sellada de Dart 3 en lugar de `Either` de un paquete externo:
/// el `switch` exhaustivo del compilador da la misma garantía sin sumar una
/// dependencia, y el código queda legible para quien no conoce programación
/// funcional.
sealed class Resultado<T> {
  const Resultado();

  const factory Resultado.exito(T valor) = Exito<T>;
  const factory Resultado.fallo(Failure falla) = Fallo<T>;

  bool get esExito => this is Exito<T>;
  bool get esFallo => this is Fallo<T>;

  /// Valor, o `null` si fue fallo.
  T? get valorONulo => switch (this) {
        Exito<T>(:final valor) => valor,
        Fallo<T>() => null,
      };

  /// Falla, o `null` si fue éxito.
  Failure? get fallaONula => switch (this) {
        Exito<T>() => null,
        Fallo<T>(:final falla) => falla,
      };

  R fold<R>(
    R Function(Failure falla) enFallo,
    R Function(T valor) enExito,
  ) =>
      switch (this) {
        Exito<T>(:final valor) => enExito(valor),
        Fallo<T>(:final falla) => enFallo(falla),
      };

  Resultado<R> map<R>(R Function(T valor) transformar) => switch (this) {
        Exito<T>(:final valor) => Exito<R>(transformar(valor)),
        Fallo<T>(:final falla) => Fallo<R>(falla),
      };
}

final class Exito<T> extends Resultado<T> {
  const Exito(this.valor);

  final T valor;

  @override
  String toString() => 'Exito($valor)';
}

final class Fallo<T> extends Resultado<T> {
  const Fallo(this.falla);

  final Failure falla;

  @override
  String toString() => 'Fallo(${falla.mensaje})';
}
