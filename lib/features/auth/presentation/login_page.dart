import 'package:app_movil/app/rutas.dart';
import 'package:app_movil/app/tema.dart';
import 'package:app_movil/app/widgets/selector_servidor_modal.dart';
import 'package:app_movil/core/config/config_providers.dart';
import 'package:app_movil/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'admin@censo.local');
  final _password = TextEditingController(text: 'Admin123!');

  bool _ocultarPassword = true;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formulario.currentState?.validate() ?? false)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _enviando = true;
      _error = null;
    });

    final falla = await ref.read(sesionProvider.notifier).iniciarSesion(
          email: _email.text.trim(),
          password: _password.text,
        );

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = falla == null ? null : '${falla.mensaje} ${falla.sugerencia}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estado = ref.watch(sesionProvider);

    final motivo = estado is SinSesion ? estado.motivo : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logotipo / Insignia Médica ─────────────────────────
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: tema.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tema.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_hospital_rounded,
                          size: 40,
                          color: tema.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Servicio de Admisión',
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Caja Petrolera de Salud — Regional Santa Cruz',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // ── Avisos de sesión previa o error ────────────────────
                    if (motivo != null) _Aviso(texto: motivo),
                    if (_error != null) _Aviso(texto: _error!, esError: true),

                    // ── Tarjeta de Formulario Elevada ──────────────────────
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon:
                                    Icon(Icons.alternate_email, size: 20),
                              ),
                              validator: (valor) {
                                final texto = valor?.trim() ?? '';
                                if (texto.isEmpty) return 'Ingresá tu correo.';
                                if (!texto.contains('@')) {
                                  return 'El correo no es válido.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: _ocultarPassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _entrar(),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon:
                                    const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _ocultarPassword = !_ocultarPassword,
                                  ),
                                  icon: Icon(
                                    _ocultarPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  tooltip: _ocultarPassword
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                ),
                              ),
                              validator: (valor) {
                                if ((valor ?? '').isEmpty) {
                                  return 'Ingresá tu contraseña.';
                                }
                                if ((valor ?? '').length < 6) {
                                  return 'La contraseña tiene al menos 6 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _enviando ? null : _entrar,
                              icon: _enviando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text(
                                'Entrar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Acceso a prueba de dictado ────────────────────────
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context)
                            .pushNamed(Rutas.diagnosticoDictado);
                      },
                      icon: const Icon(Icons.mic_none, size: 18),
                      label: const Text('Probar dictado sin iniciar sesión'),
                    ),

                    const SizedBox(height: 12),
                    const _DestinoActivo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contra qué servidor está corriendo esta compilación.
class _DestinoActivo extends ConsumerWidget {
  const _DestinoActivo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configuracionProvider);
    final tema = Theme.of(context);

    return InkWell(
      onTap: () => SelectorServidorModal.mostrar(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: TemaApp.semilla.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dns_rounded,
              size: 14,
              color: TemaApp.semilla,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${config.nombreDestino} · ${config.urlBaseApi}',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.tune_rounded,
              size: 13,
              color: TemaApp.semilla,
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.esError = false});

  final String texto;
  final bool esError;

  @override
  Widget build(BuildContext context) {
    final color = esError ? TemaApp.error : TemaApp.advertencia;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.info_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
