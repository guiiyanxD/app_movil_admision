import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/censo_diario/domain/entities/cama_prestada.dart';
import 'package:app_movil/features/censo_diario/domain/entities/servicio.dart';
import 'package:app_movil/features/censo_diario/domain/entities/tipo_movimiento_censo.dart';
import 'package:flutter/material.dart';

/// Registro de camas prestadas del servicio en la fecha.
///
/// Va **colapsada por defecto y al final del formulario**, por dos razones:
///
/// 1. No participa de ninguna fórmula. No afecta el saldo, la dotación ni el
///    cuadre: es un registro paralelo (ADR-0005, D-5). Ponerla en medio del
///    recorrido numérico interrumpiría la cadena de nueve campos que el
///    operador completa con "siguiente" sin cerrar el teclado.
/// 2. Es la única entrada del formulario sin respaldo estructurado en el papel
///    —se anota al margen, tipo "Cir = 1"— así que muchos días simplemente no
///    hay nada que cargar. Su ausencia nunca bloquea el guardado.
class SeccionCamasPrestadas extends StatefulWidget {
  const SeccionCamasPrestadas({
    required this.camas,
    required this.especialidades,
    required this.alCambiar,
    this.habilitado = true,
    super.key,
  });

  final List<CamaPrestada> camas;

  /// Especialidades con mapeo hacia vaciado. Solo esas pueden elegirse.
  final List<MapeoVaciado> especialidades;

  final ValueChanged<List<CamaPrestada>> alCambiar;
  final bool habilitado;

  @override
  State<SeccionCamasPrestadas> createState() => _SeccionCamasPrestadasState();
}

class _SeccionCamasPrestadasState extends State<SeccionCamasPrestadas> {
  bool _expandida = false;

  String _nombreDe(String especialidadId) {
    for (final e in widget.especialidades) {
      if (e.entidadId == especialidadId) return e.nombreVaciado;
    }
    // Puede pasar si el catálogo cambió entre que se cargó y ahora. Mostrar el
    // id crudo es feo, pero mucho mejor que ocultar una fila que sí se va a
    // enviar al servidor.
    return 'Especialidad $especialidadId';
  }

  int get _totalCamas =>
      widget.camas.fold(0, (suma, cama) => suma + cama.cantidad);

  Future<void> _agregar() async {
    final nueva = await _abrirDialogo();
    if (nueva == null) return;
    widget.alCambiar([...widget.camas, nueva]);
  }

  Future<void> _editar(int indice) async {
    final editada = await _abrirDialogo(inicial: widget.camas[indice]);
    if (editada == null) return;

    final copia = [...widget.camas]..[indice] = editada;
    widget.alCambiar(copia);
  }

  void _quitar(int indice) {
    final copia = [...widget.camas]..removeAt(indice);
    widget.alCambiar(copia);
  }

  Future<CamaPrestada?> _abrirDialogo({CamaPrestada? inicial}) {
    // Al editar, la propia combinación no cuenta como ocupada: si no, no se
    // podría cambiar solo la cantidad.
    final ocupadas = {
      for (final cama in widget.camas)
        if (cama != inicial) cama.claveUnicidad,
    };

    return showDialog<CamaPrestada>(
      context: context,
      builder: (_) => _DialogoCamaPrestada(
        especialidades: widget.especialidades,
        combinacionesOcupadas: ocupadas,
        inicial: inicial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sinEspecialidades = widget.especialidades.isEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: tema.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tema.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swap_horiz,
                color: tema.colorScheme.primary,
                size: 20,
              ),
            ),
            title: const Text('Camas prestadas'),
            subtitle: Text(
              widget.camas.isEmpty
                  ? 'Sin registrar'
                  : '$_totalCamas cama(s) en ${widget.camas.length} '
                      'combinación(es)',
            ),
            trailing: Icon(
              _expandida ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _expandida = !_expandida),
          ),
          if (_expandida) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pacientes de otra especialidad que ocuparon una cama de este '
                'servicio. En el formulario se anota al margen, por ejemplo '
                '«Cir = 1». No afecta el saldo ni el cuadre.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (sinEspecialidades)
              const _AvisoSinMapeo()
            else ...[
              for (var i = 0; i < widget.camas.length; i++)
                _FilaCama(
                  nombre: _nombreDe(widget.camas[i].especialidadId),
                  cama: widget.camas[i],
                  habilitado: widget.habilitado,
                  alEditar: () => _editar(i),
                  alQuitar: () => _quitar(i),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.habilitado ? _agregar : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar cama prestada'),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AvisoSinMapeo extends StatelessWidget {
  const _AvisoSinMapeo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: TemaApp.advertencia, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todavía no hay especialidades con mapeo hacia el sistema '
              'central, así que no se pueden registrar camas prestadas. El '
              'equipo de datos completa ese mapeo a mano.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaCama extends StatelessWidget {
  const _FilaCama({
    required this.nombre,
    required this.cama,
    required this.habilitado,
    required this.alEditar,
    required this.alQuitar,
  });

  final String nombre;
  final CamaPrestada cama;
  final bool habilitado;
  final VoidCallback alEditar;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esquema.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: esquema.primaryContainer,
          foregroundColor: esquema.onPrimaryContainer,
          child: Text(
            '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(cama.tipoIngreso.etiqueta),
        trailing: habilitado
            ? IconButton(
                onPressed: alQuitar,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Quitar',
              )
            : null,
        onTap: habilitado ? alEditar : null,
      ),
    );
  }
}

/// Alta y edición de una cama prestada.
class _DialogoCamaPrestada extends StatefulWidget {
  const _DialogoCamaPrestada({
    required this.especialidades,
    required this.combinacionesOcupadas,
    this.inicial,
  });

  final List<MapeoVaciado> especialidades;

  /// Claves `especialidadId::TIPO` que ya están en la lista.
  final Set<String> combinacionesOcupadas;

  final CamaPrestada? inicial;

  @override
  State<_DialogoCamaPrestada> createState() => _DialogoCamaPrestadaState();
}

class _DialogoCamaPrestadaState extends State<_DialogoCamaPrestada> {
  late String? _especialidadId = widget.inicial?.especialidadId;
  late TipoIngresoCamaPrestada _tipo =
      widget.inicial?.tipoIngreso ?? TipoIngresoCamaPrestada.directo;
  late int _cantidad = widget.inicial?.cantidad ?? 1;

  bool _estaOcupada(String especialidadId, TipoIngresoCamaPrestada tipo) =>
      widget.combinacionesOcupadas
          .contains('$especialidadId::${tipo.valorApi}');

  /// Especialidades que todavía admiten el tipo seleccionado.
  List<MapeoVaciado> get _disponibles => widget.especialidades
      .where((e) => !_estaOcupada(e.entidadId, _tipo))
      .toList();

  bool get _puedeGuardar => _especialidadId != null && _cantidad >= 1;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final disponibles = _disponibles;

    // Cambiar el tipo puede dejar inválida la especialidad ya elegida.
    if (_especialidadId != null &&
        !disponibles.any((e) => e.entidadId == _especialidadId)) {
      _especialidadId = null;
    }

    return AlertDialog(
      title: Text(
        widget.inicial == null ? 'Agregar cama prestada' : 'Editar',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tipo de ingreso', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<TipoIngresoCamaPrestada>(
              segments: [
                for (final tipo in TipoIngresoCamaPrestada.values)
                  ButtonSegment(value: tipo, label: Text(tipo.etiqueta)),
              ],
              selected: {_tipo},
              onSelectionChanged: (seleccion) =>
                  setState(() => _tipo = seleccion.first),
            ),
            const SizedBox(height: 20),
            Text('Especialidad del paciente', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            if (disponibles.isEmpty)
              Text(
                'Ya registraste todas las especialidades con este tipo de '
                'ingreso.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: TemaApp.advertencia),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _especialidadId,
                isExpanded: true,
                hint: const Text('Elegir…'),
                items: [
                  for (final e in disponibles)
                    DropdownMenuItem(
                      value: e.entidadId,
                      child: Text(e.nombreVaciado, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (valor) => setState(() => _especialidadId = valor),
              ),
            const SizedBox(height: 8),
            Text(
              'Es la especialidad del paciente, no la del servicio que presta '
              'la cama.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text('Cantidad', style: tema.textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.outlined(
                  // El backend exige al menos 1: una cama prestada de cero
                  // pacientes no es un registro, es una fila vacía.
                  onPressed: _cantidad > 1
                      ? () => setState(() => _cantidad--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Text(
                    '$_cantidad',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall,
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => setState(() => _cantidad++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puedeGuardar
              ? () => Navigator.of(context).pop(
                    CamaPrestada(
                      especialidadId: _especialidadId!,
                      cantidad: _cantidad,
                      tipoIngreso: _tipo,
                    ),
                  )
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
