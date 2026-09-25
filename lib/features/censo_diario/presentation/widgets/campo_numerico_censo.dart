import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:app_movil/features/censo_diario/presentation/state/censo_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo entero del formulario EST-1.
///
/// Diseñado para transcribir papel de noche, en una docena de servicios
/// seguidos: la métrica es campos correctos por minuto.
///
/// - `−` y `+` de 48×48 dp, para corregir de a uno sin abrir el teclado.
/// - Selecciona todo el texto al enfocar: tipear encima reemplaza, no anexa.
/// - `TextInputAction.next` encadena los 9 campos sin cerrar el teclado.
/// - Marca visible cuando el valor vino de un dictado, hasta que se guarde.
class CampoNumericoCenso extends StatefulWidget {
  const CampoNumericoCenso({
    required this.campo,
    required this.valor,
    required this.alCambiar,
    this.origen = OrigenDato.manual,
    this.resaltado = false,
    this.ultimo = false,
    this.valorSugerido,
    this.explicacionSugerencia,
    this.alAceptarSugerencia,
    super.key,
  });

  final CampoCenso campo;
  final int valor;
  final ValueChanged<int> alCambiar;
  final OrigenDato origen;

  /// Una validación apunta a este campo.
  final bool resaltado;

  /// Último del recorrido: cierra el teclado en vez de saltar al siguiente.
  final bool ultimo;

  /// Valor que el sistema deduce para este campo. `null` si no hay nada que
  /// sugerir.
  ///
  /// Es una sugerencia, no una imposición: el campo sigue siendo tipeable y el
  /// operador puede ignorarla. Esa diferencia importa cuando el valor del papel
  /// es la única forma de detectar un error en los otros campos.
  final int? valorSugerido;

  /// De dónde sale la sugerencia. Sin esto es un número que aparece por magia.
  final String? explicacionSugerencia;

  final VoidCallback? alAceptarSugerencia;

  @override
  State<CampoNumericoCenso> createState() => _CampoNumericoCensoState();
}

class _CampoNumericoCensoState extends State<CampoNumericoCenso> {
  late final TextEditingController _controlador;
  late final FocusNode _foco;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.valor.toString());
    _foco = FocusNode()..addListener(_alCambiarFoco);
  }

  void _alCambiarFoco() {
    if (_foco.hasFocus) {
      _controlador.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controlador.text.length,
      );
    }
  }

  @override
  void didUpdateWidget(CampoNumericoCenso viejo) {
    super.didUpdateWidget(viejo);
    // El valor puede cambiar desde afuera (dictado confirmado). Se sincroniza
    // solo si el campo no está siendo editado, para no pisar lo que se tipea.
    if (widget.valor != viejo.valor && !_foco.hasFocus) {
      _controlador.text = widget.valor.toString();
    }
  }

  @override
  void dispose() {
    _foco
      ..removeListener(_alCambiarFoco)
      ..dispose();
    _controlador.dispose();
    super.dispose();
  }

  void _ajustar(int delta) {
    final nuevo = (widget.valor + delta).clamp(0, 999);
    _controlador.text = nuevo.toString();
    widget.alCambiar(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final tieneValor = widget.valor > 0;

    return Semantics(
      label: widget.campo.etiqueta,
      value: widget.valor.toString(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: widget.resaltado
              ? TemaApp.advertencia.withValues(alpha: 0.08)
              : tieneValor
                  ? esquema.surfaceContainerLow
                  : esquema.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.resaltado
                ? TemaApp.advertencia
                : tieneValor
                    ? esquema.primary.withValues(alpha: 0.25)
                    : esquema.outlineVariant.withValues(alpha: 0.4),
            width: widget.resaltado ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.campo.etiqueta,
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: widget.resaltado
                          ? TemaApp.advertencia
                          : tieneValor
                              ? esquema.onSurface
                              : esquema.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.origen == OrigenDato.voz)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: esquema.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic,
                            size: 12, color: esquema.onPrimaryContainer),
                        const SizedBox(width: 3),
                        Text(
                          'Dictado',
                          style: tema.textTheme.labelSmall?.copyWith(
                            color: esquema.onPrimaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.campo.ayudaFormulario,
              style: tema.textTheme.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: widget.valor > 0 ? () => _ajustar(-1) : null,
                  icon: const Icon(Icons.remove),
                  tooltip: 'Restar uno',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(44, 44),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controlador,
                    focusNode: _foco,
                    keyboardType: TextInputType.number,
                    textInputAction: widget.ultimo
                        ? TextInputAction.done
                        : TextInputAction.next,
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tieneValor
                          ? esquema.primary
                          : esquema.onSurfaceVariant,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: esquema.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color:
                                esquema.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: tieneValor
                              ? esquema.primary.withValues(alpha: 0.3)
                              : esquema.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: esquema.primary, width: 2),
                      ),
                      errorText: widget.resaltado ? '' : null,
                      errorStyle: const TextStyle(height: 0),
                    ),
                    onChanged: (texto) =>
                        widget.alCambiar(int.tryParse(texto) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _ajustar(1),
                  icon: const Icon(Icons.add),
                  tooltip: 'Sumar uno',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ],
            ),
            if (widget.valorSugerido != null) _sugerencia(context),
          ],
        ),
      ),
    );
  }

  Widget _sugerencia(BuildContext context) {
    final tema = Theme.of(context);
    final sugerido = widget.valorSugerido!;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: tema.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.alAceptarSugerencia == null
              ? null
              : () {
                  _controlador.text = sugerido.toString();
                  widget.alAceptarSugerencia!.call();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deberían ser ',
                        style: tema.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (widget.explicacionSugerencia != null)
                        Text(
                          widget.explicacionSugerencia!,
                          style: tema.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (widget.alAceptarSugerencia != null)
                  Text(
                    'Usar',
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: tema.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
