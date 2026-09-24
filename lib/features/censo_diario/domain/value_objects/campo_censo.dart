/// Los 9 campos numéricos que la app envía al backend, más las referencias
/// que solo se muestran.
///
/// El orden de la enumeración es el **orden de captura en pantalla**, que sigue
/// el orden de conteo de bloques del formulario impreso — no el orden de las
/// filas del RESUMEN (ver SPEC-002 §2.1, decisión D-3 del ADR-0005).
enum CampoCenso {
  ingreso(
    campoApi: 'ingreso',
    etiqueta: 'Ingresos por admisión',
    ayudaFormulario: 'contá el bloque INGRESO (POR ADMISIÓN)',
  ),
  ingresoTraslado(
    campoApi: 'ingresoTraslado',
    etiqueta: 'Ingresos por traslado',
    ayudaFormulario: 'contá el bloque INGRESO — POR TRASLADO DEL SERVICIO',
  ),
  egreso(
    campoApi: 'egreso',
    etiqueta: 'Egresos por salida',
    // La etiqueta impresa quedó desactualizada: ahí se anotan los egresos
    // directos. Se muestra para que el operador ubique la fila en el papel,
    // pero NO se usa como rótulo del campo (ADR-0005, D-3).
    ayudaFormulario: 'en el formulario: fila «Ingresos y egresos del mismo día»',
  ),
  egresoTraslado(
    campoApi: 'egresoTraslado',
    etiqueta: 'Egresos por traslado',
    ayudaFormulario: 'contá el bloque EGRESO — POR TRASLADO DEL SERVICIO',
  ),
  obito(
    campoApi: 'obito',
    etiqueta: 'Óbitos',
    ayudaFormulario: 'en el formulario: fila «Pacientes fallecidos»',
  ),
  aislamiento(
    campoApi: 'aislamiento',
    etiqueta: 'Camas en aislamiento',
    ayudaFormulario: 'sin fila propia en el formulario impreso',
  ),
  bloqueada(
    campoApi: 'bloqueada',
    etiqueta: 'Camas bloqueadas',
    ayudaFormulario: 'sin fila propia en el formulario impreso',
  ),
  libre(
    campoApi: 'libre',
    etiqueta: 'Camas libres',
    ayudaFormulario: 'en el formulario: fila «Números de camas libres»',
  ),
  total(
    campoApi: 'total',
    etiqueta: 'Saldo de pacientes a las 24 horas',
    ayudaFormulario: 'en el formulario: fila «Saldo pacientes a las 24 horas»',
  );

  const CampoCenso({
    required this.campoApi,
    required this.etiqueta,
    required this.ayudaFormulario,
  });

  /// Nombre exacto de la propiedad en el JSON de `POST /carga-manual`.
  final String campoApi;

  /// Rótulo que ve el operador. Nunca reproduce etiquetas impresas obsoletas.
  final String etiqueta;

  /// Texto auxiliar que ubica el dato en el formulario de papel.
  final String ayudaFormulario;

  /// `true` si el campo cuenta camas en lugar de movimientos de paciente.
  bool get esCama =>
      this == aislamiento || this == bloqueada || this == libre;
}
