import 'package:app_movil/app/tema.dart';
import 'package:app_movil/core/config/ambiente_servidor.dart';
import 'package:app_movil/core/config/configuracion_app.dart';
import 'package:app_movil/core/config/gestor_servidor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal interactivo para seleccionar el servidor y probar la conectividad en vivo.
class SelectorServidorModal extends ConsumerStatefulWidget {
  const SelectorServidorModal({super.key});

  static Future<void> mostrar(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SelectorServidorModal(),
    );
  }

  @override
  ConsumerState<SelectorServidorModal> createState() =>
      _SelectorServidorModalState();
}

class _SelectorServidorModalState extends ConsumerState<SelectorServidorModal> {
  late AmbienteServidor _seleccionado;
  late TextEditingController _urlPersonalizadaCtrl;

  @override
  void initState() {
    super.initState();
    final configActual = ref.read(gestorServidorProvider).config;
    _seleccionado = configActual.ambiente;
    _urlPersonalizadaCtrl = TextEditingController(
      text: _seleccionado == AmbienteServidor.personalizado
          ? configActual.urlBaseApi
          : '',
    );
  }

  @override
  void dispose() {
    _urlPersonalizadaCtrl.dispose();
    super.dispose();
  }

  String get _urlObjetivo {
    if (_seleccionado == AmbienteServidor.personalizado) {
      return _urlPersonalizadaCtrl.text.trim();
    }
    return _seleccionado.url;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gestorState = ref.watch(gestorServidorProvider);
    final probando = gestorState.probandoConexion;
    final resultado = gestorState.resultadoPrueba;

    return Container(
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TemaApp.semilla.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dns_rounded, color: TemaApp.semilla),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Servidor de la API',
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Elige o ingresa la IP del backend',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            ...AmbienteServidor.values.map((ambiente) {
              final esSeleccionado = _seleccionado == ambiente;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: esSeleccionado
                        ? TemaApp.semilla
                        : tema.colorScheme.outlineVariant,
                    width: esSeleccionado ? 1.8 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: esSeleccionado
                      ? TemaApp.semilla.withOpacity(0.05)
                      : Colors.transparent,
                ),
                child: RadioListTile<AmbienteServidor>(
                  value: ambiente,
                  groupValue: _seleccionado,
                  activeColor: TemaApp.semilla,
                  title: Text(
                    ambiente.nombre,
                    style: TextStyle(
                      fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    ambiente == AmbienteServidor.personalizado
                        ? 'Ingresar IP manual (ej: ${AmbienteServidor.ejemploPersonalizado})'
                        : '${ambiente.descripcion}\n${ambiente.url}',
                    style: tema.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _seleccionado = val);
                    }
                  },
                ),
              );
            }),
            if (_seleccionado == AmbienteServidor.personalizado) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _urlPersonalizadaCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL o IP Personalizada',
                  hintText: AmbienteServidor.hintPersonalizado,
                  prefixIcon: Icon(Icons.link_rounded),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
            const SizedBox(height: 12),
            // Botón de prueba y estado de conectividad
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: probando
                  ? null
                  : () async {
                      await ref
                          .read(gestorServidorProvider.notifier)
                          .probarConexion(_urlObjetivo);
                    },
              icon: probando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check_rounded, size: 20),
              label: Text(probando ? 'Probando conexión...' : 'Probar conexión ahora'),
            ),
            if (resultado != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: resultado.exitoso
                      ? TemaApp.exito.withOpacity(0.1)
                      : TemaApp.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: resultado.exitoso ? TemaApp.exito : TemaApp.error,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      resultado.exitoso
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: resultado.exitoso ? TemaApp.exito : TemaApp.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        resultado.exitoso
                            ? 'Conexión exitosa (${resultado.latenciaMs} ms)'
                            : resultado.mensaje,
                        style: TextStyle(
                          color: resultado.exitoso ? TemaApp.exito : TemaApp.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: TemaApp.semilla,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                await ref.read(gestorServidorProvider.notifier).cambiarServidor(
                      ambiente: _seleccionado,
                      urlPersonalizada: _seleccionado == AmbienteServidor.personalizado
                          ? _urlPersonalizadaCtrl.text.trim()
                          : null,
                    );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Servidor configurado: $_urlObjetivo'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar y usar este servidor'),
            ),
          ],
        ),
      ),
    );
  }
}
