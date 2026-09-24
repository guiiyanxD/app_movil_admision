import 'package:app_movil/app/bootstrap.dart';

/// Punto de entrada. Todo lo que decide dependencias vive en `bootstrap()`,
/// para que exista **un solo** lugar donde mirar cuando algo está mal cableado
/// (ADR-0006, D-2).
void main() => bootstrap();
