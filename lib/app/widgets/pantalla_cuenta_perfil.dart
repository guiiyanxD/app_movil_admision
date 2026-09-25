import 'package:app_movil/app/rutas.dart';
import 'package:app_movil/app/tema.dart';
import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vista de perfil del operador, estado del sistema y herramientas de diagnóstico.
class PantallaCuentaPerfil extends ConsumerWidget {
  const PantallaCuentaPerfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final sesion = ref.watch(sesionActivaProvider);
    final config = ref.watch(configuracionProvider);

    final iniciales = _obtenerIniciales(sesion?.usuario.nombreCompleto ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta y Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Tarjeta de Usuario ───────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: tema.colorScheme.primaryContainer,
                    foregroundColor: tema.colorScheme.onPrimaryContainer,
                    child: Text(
                      iniciales,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sesion?.usuario.nombreCompleto ?? 'Operador',
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sesion?.usuario.email ?? '',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tema.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sesion?.rol.etiqueta ?? 'Sin rol',
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: tema.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Conexión y Sistema ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'INFORMACIÓN DEL SISTEMA',
              style: tema.textTheme.labelMedium?.copyWith(
                color: tema.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Servidor: ${config.nombreDestino}',
                          style: tema.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.link, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          config.urlBaseApi,
                          style: tema.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Botón Cerrar Sesión ────────────────────────────────────
          FilledButton.tonalIcon(
            onPressed: () => _confirmarCerrarSesion(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: FilledButton.styleFrom(
              backgroundColor: TemaApp.error.withValues(alpha: 0.1),
              foregroundColor: TemaApp.error,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _obtenerIniciales(String nombreCompleto) {
    final partes = nombreCompleto.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return 'U';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  void _confirmarCerrarSesion(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a ingresar tus credenciales para continuar registrando el censo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref.read(sesionProvider.notifier).cerrarSesion();
            },
            style: FilledButton.styleFrom(backgroundColor: TemaApp.error),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}
