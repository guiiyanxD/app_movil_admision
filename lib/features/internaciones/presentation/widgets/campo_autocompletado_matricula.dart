import 'dart:async';
import 'package:app_movil/features/internaciones/domain/entities/paciente.dart';
import 'package:app_movil/features/internaciones/presentation/providers/ingreso_hc2_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampoMatriculaAutocomplete extends ConsumerStatefulWidget {
  const CampoMatriculaAutocomplete({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.onSelected,
    this.onChanged,
    this.filtroTipoPaciente,
  });

  final TextEditingController controller;
  final String labelText;
  final Icon? prefixIcon;
  final void Function(Paciente)? onSelected;
  final void Function(String)? onChanged;
  final String? filtroTipoPaciente;

  @override
  ConsumerState<CampoMatriculaAutocomplete> createState() =>
      _CampoMatriculaAutocompleteState();
}

class _CampoMatriculaAutocompleteState
    extends ConsumerState<CampoMatriculaAutocomplete> {
  // Timer para el debounce
  Timer? _debounce;
  Iterable<Paciente> _ultimasOpciones = const [];
  String _ultimaConsulta = '';
  bool _buscando = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<Iterable<Paciente>> _buscarSugerencias(
      TextEditingValue textEditingValue) async {
    final consulta = textEditingValue.text.trim().toUpperCase();
    if (consulta.length < 3) {
      return const Iterable<Paciente>.empty();
    }

    if (consulta == _ultimaConsulta) {
      return _ultimasOpciones;
    }

    final completer = Completer<Iterable<Paciente>>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _buscando = true);
      try {
        final repo = ref.read(pacientesRepositoryProvider);
        final resultado = await repo.buscarSugerencias(
          consulta,
          tipoPaciente: widget.filtroTipoPaciente,
        );
        if (resultado.esExito) {
          _ultimaConsulta = consulta;
          _ultimasOpciones = resultado.valorONulo ?? const [];
          completer.complete(_ultimasOpciones);
        } else {
          completer.complete(const Iterable<Paciente>.empty());
        }
      } catch (_) {
        completer.complete(const Iterable<Paciente>.empty());
      } finally {
        if (mounted) setState(() => _buscando = false);
      }
    });

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<Paciente>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: _buscarSugerencias,
          displayStringForOption: (option) => option.matricula,
          onSelected: (paciente) {
            widget.onSelected?.call(paciente);
            widget.onChanged?.call(paciente.matricula);
          },
          fieldViewBuilder: (context, textEditingController, focusNode,
              onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: widget.labelText,
                prefixIcon: widget.prefixIcon,
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (val) {
                widget.onChanged?.call(val);
              },
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final tema = Theme.of(context);
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Material(
                  elevation: 8.0,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  color: tema.colorScheme.surface,
                  shadowColor: Colors.black26,
                  child: ConstrainedBox(
                    // Max 4 items roughly (approx 65 height per item)
                    constraints: BoxConstraints(
                      maxHeight: 260,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, i) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        final nombreCompleto =
                            '${option.apellidoPaterno} ${option.apellidoMaterno ?? ''} ${option.nombres}'.trim();
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.matricula,
                                  style: tema.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nombreCompleto,
                                  style: tema.textTheme.bodyMedium?.copyWith(
                                    color: tema.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
