import 'dart:async';

import 'package:app_movil/app/tema.dart';
import 'package:flutter/material.dart';

/// Retroalimentación mientras el motor escucha.
///
/// ## Por qué la transcripción parcial va primero
///
/// El operador necesita tres certezas: que arrancó, que lo están escuchando y
/// cuánto le queda. La tercera es la menos importante de las tres, y sin
/// embargo es la que uno tiende a resolver primero poniendo un cronómetro.
///
/// Ver las palabras apareciendo mientras se habla responde las tres de una vez
/// y es el mecanismo que hace que un dictado se sienta vivo. La amplitud del
/// micrófono es el respaldo para cuando el motor todavía no entendió nada: sin
/// ella, un silencio de reconocimiento es indistinguible de un micrófono roto.
///
/// ## Por qué el contador es un anillo y no números grandes
///
/// El enunciado típico dura dos segundos contra un tope de 45. Un contador
/// prominente pondría presión de tiempo sobre algo que nunca se acerca al
/// límite, y además apuntaría al criterio equivocado: lo que suele cerrar la
/// sesión no es el tope, es el silencio que detecta Android. El anillo informa
/// sin dominar, y los segundos aparecen en chico solo cuando de verdad quedan
/// pocos.
class PanelEscuchaActiva extends StatefulWidget {
  const PanelEscuchaActiva({
    required this.transcripcionParcial,
    required this.nivel,
    required this.inicio,
    required this.duracionMaxima,
    required this.alConfirmar,
    required this.alCancelar,
    super.key,
  });

  /// Lo que el motor entendió hasta ahora. Vacío al empezar.
  final String transcripcionParcial;

  /// Amplitud normalizada 0–1.
  final double nivel;

  final DateTime inicio;
  final Duration duracionMaxima;

  /// "Listo": cierra la escucha **conservando** lo dictado.
  final VoidCallback alConfirmar;

  /// "Cancelar": descarta la sesión.
  final VoidCallback alCancelar;

  @override
  State<PanelEscuchaActiva> createState() => _PanelEscuchaActivaState();
}

class _PanelEscuchaActivaState extends State<PanelEscuchaActiva> {
  Timer? _reloj;
  Duration _transcurrido = Duration.zero;

  /// Umbral a partir del cual el tiempo restante pasa a ser información
  /// accionable y se muestra en números.
  static const Duration _avisoFinal = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _transcurrido = DateTime.now().difference(widget.inicio));
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Duration get _restante {
    final r = widget.duracionMaxima - _transcurrido;
    return r.isNegative ? Duration.zero : r;
  }

  double get _fraccionRestante {
    final total = widget.duracionMaxima.inMilliseconds;
    if (total <= 0) return 0;
    return (_restante.inMilliseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hayTexto = widget.transcripcionParcial.trim().isNotEmpty;
    final porTerminar = _restante <= _avisoFinal;

    return Material(
      elevation: 12,
      color: tema.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AnilloEscucha(
                    fraccion: _fraccionRestante,
                    nivel: widget.nivel,
                    alarmante: porTerminar,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Escuchando',
                              style: tema.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: tema.colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            // Los segundos solo aparecen cuando queda poco: el
                            // resto del tiempo serían ruido con presión.
                            if (porTerminar)
                              Text(
                                '${_restante.inSeconds} s',
                                style: tema.textTheme.labelLarge?.copyWith(
                                  color: TemaApp.advertencia,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _Transcripcion(
                          texto: widget.transcripcionParcial,
                          hayTexto: hayTexto,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.alCancelar,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: widget.alConfirmar,
                      icon: const Icon(Icons.check),
                      // "Listo" comunica "terminé de hablar". "Detener" sonaba
                      // a interrumpir, que es justo lo que ya no hace.
                      label: const Text('Listo'),
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

class _Transcripcion extends StatelessWidget {
  const _Transcripcion({required this.texto, required this.hayTexto});

  final String texto;
  final bool hayTexto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Text(
        hayTexto ? texto : 'Hablá ahora…',
        key: ValueKey(hayTexto),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: hayTexto
            ? tema.textTheme.titleMedium
            : tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
      ),
    );
  }
}

/// Micrófono con anillo de tiempo restante y halo de amplitud.
///
/// Dos señales en un solo objeto: el anillo se vacía con el tiempo, el halo
/// late con la voz. Ninguna de las dos depende solo del color.
class _AnilloEscucha extends StatelessWidget {
  const _AnilloEscucha({
    required this.fraccion,
    required this.nivel,
    required this.alarmante,
  });

  final double fraccion;
  final double nivel;
  final bool alarmante;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = alarmante ? TemaApp.advertencia : tema.colorScheme.primary;

    return SizedBox(
      width: TemaApp.objetivoTactil,
      height: TemaApp.objetivoTactil,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo de amplitud: crece con la voz. Es la prueba de que el
          // micrófono está captando aunque el motor no haya entendido nada.
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28 + nivel * 20,
            height: 28 + nivel * 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: fraccion,
              strokeWidth: 3,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          Icon(Icons.mic, color: color, size: 20),
        ],
      ),
    );
  }
}
