import 'package:app_movil/app/tema.dart';
import 'package:app_movil/core/formato/momento_local.dart';
import 'package:app_movil/features/censo_diario/domain/entities/carga_guardada.dart';
import 'package:app_movil/features/censo_diario/presentation/widgets/indicadores_censo.dart';
import 'package:flutter/material.dart';

/// Quién cargó este servicio y cuándo (SPEC-003, D-5 y CA-08).
///
/// Reemplaza al aviso de sobrescritura. Con la precarga andando ya no hay
/// valores invisibles que advertir —están en los campos—, pero sigue faltando
/// lo que ningún campo dice: que lo que estás por reemplazar lo cargó otra
/// persona hace una hora. Varias personas pueden tocar la misma fecha, y eso
/// cambia la decisión.
class LineaProcedencia extends StatelessWidget {
  const LineaProcedencia({required this.carga, this.ahora, super.key});

  final CargaGuardada carga;

  /// Inyectable para que los tests no dependan del reloj.
  final DateTime? ahora;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono además del texto: ningún estado se comunica solo por color
          // (SPEC-002, §8.4). No es tocable, así que no aplica el objetivo
          // táctil de 48 dp.
          Icon(Icons.history, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _texto,
              style: tema.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Degrada de a partes.
  ///
  /// `creadoPorNombre` y `actualizadoEn` son opcionales en el contrato: son
  /// metadatos de presentación, y que el backend deje de mandarlos no puede
  /// tapar el hecho —que sí conocemos— de que el servicio ya venía cargado.
  String get _texto {
    final quien = carga.creadoPorNombre;
    final cuando = carga.actualizadoEn;
    final momento = cuando == null ? null : momentoLocal(cuando, ahora: ahora);

    if (quien != null && momento != null) {
      return 'Cargado por $quien · $momento';
    }
    if (quien != null) return 'Cargado por $quien';
    if (momento != null) return 'Cargado $momento';
    return 'Estos valores ya estaban guardados';
  }
}

/// No se pudo leer lo guardado (SPEC-003, D-3, R-11 y CA-07).
///
/// Es la contrapartida de haber retirado el `keepAlive`: el formulario abrió en
/// cero y, si el servidor tenía una carga previa, guardar la reemplaza sin que
/// nadie la haya visto. Se prefiere un fallo explícito a presentar ceros como
/// si fueran el estado real del servidor.
class AvisoLecturaFallida extends StatelessWidget {
  const AvisoLecturaFallida({super.key});

  @override
  Widget build(BuildContext context) {
    return const TarjetaAviso(
      icono: Icons.cloud_off,
      color: TemaApp.advertencia,
      titulo: 'No se pudo leer lo guardado',
      cuerpo: 'El formulario abrió en cero. Si este servicio ya tenía carga '
          'para esta fecha, no la estás viendo y guardar la reemplazaría por '
          'completo. Revisá la conexión y volvé a entrar para verla.',
    );
  }
}
