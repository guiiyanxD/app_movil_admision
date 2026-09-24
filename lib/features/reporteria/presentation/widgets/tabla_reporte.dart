import 'package:app_movil/app/tema.dart';
import 'package:app_movil/features/reporteria/domain/usecases/armar_matriz_reporte.dart';
import 'package:flutter/material.dart';

/// La matriz período × servicio en pantalla.
///
/// Se desplaza en horizontal: con doce servicios más el total no hay teléfono
/// donde entre, y comprimir los nombres hasta que quepan haría ilegible
/// justamente lo que identifica cada columna. Es el mismo compromiso que toma
/// la web, que además dispone de una pantalla mucho más ancha (D-3).
class TablaReporte extends StatelessWidget {
  const TablaReporte({required this.matriz, super.key});

  final MatrizReporte matriz;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.swipe,
                size: 16,
                color: tema.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Deslizá la tabla para ver todos los servicios.',
                  style: tema.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              tema.colorScheme.primaryContainer,
            ),
            headingTextStyle: tema.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: tema.colorScheme.onPrimaryContainer,
            ),
            dataTextStyle: tema.textTheme.bodySmall,
            columnSpacing: 18,
            horizontalMargin: 12,
            columns: [
              const DataColumn(label: Text('Período')),
              for (final servicio in matriz.servicios)
                DataColumn(label: Text(servicio), numeric: true),
              const DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: [
              for (final fila in matriz.filas)
                DataRow(
                  cells: [
                    DataCell(Text(fila.periodo)),
                    for (final valor in fila.valores)
                      DataCell(Text('$valor', style: _tenueSiEsCero(valor))),
                    DataCell(
                      Text(
                        '${fila.total}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              // La fila de totales cierra la tabla, como en el impreso. Es la
              // misma aritmética que va al PDF, no un cálculo aparte (D-5).
              DataRow(
                color: WidgetStatePropertyAll(
                  tema.colorScheme.surfaceContainerHighest,
                ),
                cells: [
                  const DataCell(
                    Text(
                      'TOTAL',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  for (final total in matriz.totalesPorServicio)
                    DataCell(
                      Text(
                        '$total',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  DataCell(
                    Text(
                      '${matriz.totalGeneral}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: TemaApp.semilla,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Los ceros se atenúan para que las cifras que sí tienen valor salten a la
  /// vista. En una matriz de trescientas celdas mayormente en cero, ese
  /// contraste es la diferencia entre leerla y escanearla.
  TextStyle? _tenueSiEsCero(int valor) =>
      valor == 0 ? const TextStyle(color: Colors.grey) : null;
}
