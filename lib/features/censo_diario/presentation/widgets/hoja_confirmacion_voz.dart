import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/censo_diario/domain/entities/propuesta_voz.dart';
import 'package:app_movil/features/censo_diario/domain/value_objects/campo_censo.dart';
import 'package:flutter/material.dart';

/// Pre-carga y confirmación de un dictado.
///
/// Es la compuerta que exige el criterio de calidad del proyecto: lo dictado
/// **no toca el formulario** hasta que el operador decide acá, y ni siquiera
/// entonces se persiste — eso requiere el gesto aparte de "Guardar servicio".
///
/// Reglas de la pantalla (SPEC-002 §6.4):
/// 1. La transcripción literal se muestra siempre, arriba del diff.
/// 2. Cada campo tiene su casilla; los de confianza baja llegan desmarcados.
/// 3. Las sobrescrituras de un valor tipeado a mano se destacan.
/// 4. Los fragmentos no reconocidos se listan de forma explícita.
/// 5. No se puede cerrar por gesto ni por back sin elegir una acción.
class HojaConfirmacionVoz extends StatelessWidget {
  const HojaConfirmacionVoz({
    required this.propuesta,
    required this.alAlternar,
    required this.alAplicar,
    required this.alDescartar,
    required this.alRepetir,
    super.key,
  });

  final PropuestaVoz propuesta;
  final void Function(CampoCenso campo, {required bool aceptado}) alAlternar;
  final VoidCallback alAplicar;
  final VoidCallback alDescartar;
  final VoidCallback alRepetir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final aceptados = propuesta.aceptados.length;

    // Cerrar la hoja por accidente no debe aplicar nada en silencio, ni
    // dejar al operador sin saber qué pasó con lo que dictó.
    return PopScope(
      canPop: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: tema.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Revisá antes de aplicar',
                      style: tema.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nada se guarda todavía. Al aplicar, los valores pasan '
                      'al formulario y después tenés que guardar el servicio.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Transcripcion(texto: propuesta.transcripcion),
                    // Va **antes** de los campos, no al final. Estaba debajo de
                    // todo, dentro de un `ListView` que construye por demanda:
                    // con la hoja al 75 % quedaba fuera de la ventana, así que
                    // no se construía y el operador podía aplicar sin haber
                    // visto nunca que parte del dictado no se entendió. El
                    // botón «Aplicar» sí está siempre visible, fuera del
                    // scroll. Un dictado entendido a medias no puede
                    // presentarse como éxito total (SPEC-002).
                    if (propuesta.fragmentosNoReconocidos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _NoReconocidos(
                        fragmentos: propuesta.fragmentosNoReconocidos,
                      ),
                    ],
                    const SizedBox(height: 16),
                    for (final campo in propuesta.campos)
                      _FilaCampo(campo: campo, alAlternar: alAlternar),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _Acciones(
                aceptados: aceptados,
                alAplicar: alAplicar,
                alDescartar: alDescartar,
                alRepetir: alRepetir,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Transcripcion extends StatelessWidget {
  const _Transcripcion({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hearing, size: 16, color: tema.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Lo que entendió', style: tema.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text('«$texto»', style: tema.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _FilaCampo extends StatelessWidget {
  const _FilaCampo({required this.campo, required this.alAlternar});

  final CampoPropuesto campo;
  final void Function(CampoCenso campo, {required bool aceptado}) alAlternar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CheckboxListTile(
        value: campo.aceptado,
        onChanged: (valor) => alAlternar(campo.campo, aceptado: valor ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          campo.campo.etiqueta,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${campo.valorAnterior ?? 0}',
                  style: tema.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Text(
                  '${campo.valorPropuesto}',
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (campo.esSobrescritura)
              const _Etiqueta(
                icono: Icons.edit_note,
                color: TemaApp.advertencia,
                texto: 'Reemplaza un valor que ya habías cargado',
              ),
            if (campo.confianzaBaja)
              const _Etiqueta(
                icono: Icons.help_outline,
                color: TemaApp.error,
                texto: 'Reconocimiento poco confiable. Verificá antes de '
                    'aceptarlo.',
              ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.icono,
    required this.color,
    required this.texto,
  });

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoReconocidos extends StatelessWidget {
  const _NoReconocidos({required this.fragmentos});

  final List<String> fragmentos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      color: TemaApp.advertencia.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.report_gmailerrorred,
              size: 20,
              color: TemaApp.advertencia,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esto no se pudo interpretar',
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: TemaApp.advertencia,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fragmentos.join(' · '),
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.aceptados,
    required this.alAplicar,
    required this.alDescartar,
    required this.alRepetir,
  });

  final int aceptados;
  final VoidCallback alAplicar;
  final VoidCallback alDescartar;
  final VoidCallback alRepetir;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: aceptados == 0 ? null : alAplicar,
                  icon: const Icon(Icons.check),
                  label: Text(
                    aceptados == 0
                        ? 'No hay campos seleccionados'
                        : 'Aplicar $aceptados '
                            '${aceptados == 1 ? 'campo' : 'campos'}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: alRepetir,
                      icon: const Icon(Icons.mic),
                      label: const Text('Volver a dictar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: alDescartar,
                      icon: const Icon(Icons.close),
                      label: const Text('Descartar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
