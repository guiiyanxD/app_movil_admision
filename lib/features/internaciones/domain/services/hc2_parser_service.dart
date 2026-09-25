import 'package:app_movil/features/internaciones/domain/entities/datos_ingreso_hc2.dart';

/// Resultado de la decodificación algorítmica de una matrícula de la CPS.
class InfoMatriculaCPS {
  const InfoMatriculaCPS({
    required this.matricula,
    required this.fechaNacimiento,
    required this.sexo,
    required this.iniciales,
  });

  final String matricula;
  final DateTime fechaNacimiento;
  final String sexo; // 'masculino' | 'femenino'
  final String iniciales;
}

/// Desglose de nombre completo en apellidos y nombres apoyado en iniciales.
class DesgloseNombre {
  const DesgloseNombre({
    required this.apellidoPaterno,
    required this.nombres,
    this.apellidoMaterno,
  });

  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String nombres;
}

/// Servicio especializado en decodificar texto reconocido por OCR desde
/// formularios HC-2 de la Caja Petrolera de Salud.
class HC2ParserService {
  const HC2ParserService();

  static final RegExp _regexMatricula =
      RegExp(r'([12]\d{3})(\d{2})(\d{2})([A-Z]{3,4}\d?)');

  /// Decodifica una matrícula de la CPS en fecha de nacimiento, sexo e iniciales.
  ///
  /// Regla institucional de codificación:
  /// - `YYYY`: Año de nacimiento (4 dígitos).
  /// - `MM`: Mes codificado por sexo. Varones = `01-12`. Mujeres = `51-62` (Mes + 50).
  /// - `DD`: Día de nacimiento (2 dígitos).
  /// - `III`: Iniciales de apellidos y nombre.
  InfoMatriculaCPS? decodificarMatricula(String matricula) {
    final clean = matricula.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final match = _regexMatricula.firstMatch(clean);
    if (match == null) return null;

    final anho = int.tryParse(match.group(1)!);
    final mesRaw = int.tryParse(match.group(2)!);
    final dia = int.tryParse(match.group(3)!);
    final iniciales = match.group(4)!;

    if (anho == null || mesRaw == null || dia == null) return null;

    final String sexo;
    final int mesReal;

    if (mesRaw > 50 && mesRaw <= 62) {
      sexo = 'femenino';
      mesReal = mesRaw - 50;
    } else if (mesRaw >= 1 && mesRaw <= 12) {
      sexo = 'masculino';
      mesReal = mesRaw;
    } else {
      // Mes fuera de rango normal
      return null;
    }

    try {
      final fechaNac = DateTime.utc(anho, mesReal, dia);
      return InfoMatriculaCPS(
        matricula: clean,
        fechaNacimiento: fechaNac,
        sexo: sexo,
        iniciales: iniciales,
      );
    } on Exception {
      return null;
    }
  }

  /// Desglosa un nombre completo ("ZABALA BURGOS HUGO") apoyándose en las
  /// iniciales de la matrícula (ej. "ZBH") cuando estén disponibles.
  DesgloseNombre desglosarNombre(String nombreCompleto, {String? iniciales}) {
    final palabras = nombreCompleto
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (palabras.isEmpty) {
      return const DesgloseNombre(apellidoPaterno: '', nombres: '');
    }

    if (palabras.length == 1) {
      return DesgloseNombre(
        apellidoPaterno: palabras[0].toUpperCase(),
        nombres: '',
      );
    }

    if (palabras.length == 2) {
      // Si son 2 palabras:
      // Si coincide con iniciales de 1 apellido (ej. Z y H para Zabala Hugo)
      return DesgloseNombre(
        apellidoPaterno: palabras[0].toUpperCase(),
        nombres: palabras[1].toUpperCase(),
      );
    }

    if (palabras.length == 3) {
      // Clásico: PATERNO MATERNO NOMBRE
      return DesgloseNombre(
        apellidoPaterno: palabras[0].toUpperCase(),
        apellidoMaterno: palabras[1].toUpperCase(),
        nombres: palabras[2].toUpperCase(),
      );
    }

    // 4 o más palabras (ej. "SUAREZ RUIZ JENNY CRISTINA" o apellidos compuestos)
    final cleanInit = iniciales?.replaceAll(RegExp('[^A-Z]'), '') ?? '';
    if (cleanInit.length >= 3) {
      // Si la 2da palabra empieza con la 2da inicial y la 3ra con la 3ra inicial:
      if (palabras[1].toUpperCase().startsWith(cleanInit[1]) &&
          palabras[2].toUpperCase().startsWith(cleanInit[2])) {
        return DesgloseNombre(
          apellidoPaterno: palabras[0].toUpperCase(),
          apellidoMaterno: palabras[1].toUpperCase(),
          nombres: palabras.sublist(2).join(' ').toUpperCase(),
        );
      }
    }

    // Fallback estándar para Bolivia: 2 apellidos y resto nombres
    return DesgloseNombre(
      apellidoPaterno: palabras[0].toUpperCase(),
      apellidoMaterno: palabras[1].toUpperCase(),
      nombres: palabras.sublist(2).join(' ').toUpperCase(),
    );
  }

  /// Parsea el texto OCR completo de un Formulario HC-2 y extrae todos los campos.
  DatosIngresoHC2 parsear(String textoCompleto) {
    // Normalizar espacios y saltos de línea
    final texto = textoCompleto.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // ── 1. Matrícula y Datos del Paciente ──────────────────────────────────
    final matriculaPaciente = _extraerMatriculaPaciente(texto);
    final infoMatricula = matriculaPaciente != null
        ? decodificarMatricula(matriculaPaciente)
        : null;

    final nombresYApellidos = _extraerNombresYApellidos(
      texto,
      matriculaConocida: matriculaPaciente,
      inicialesConocidas: infoMatricula?.iniciales,
    );

    // ── 2. Tipo de Paciente (Asegurado vs Beneficiario) ────────────────────
    final tipoPacStr = _extraerCampo(
      texto,
      RegExp(
        r'Tipo\.?\s*Pac(?:iente)?[:\s]+([A-Za-záéíóúÁÉÍÓÚÑ]+)',
        caseSensitive: false,
      ),
    );
    final tipoPaciente =
        (tipoPacStr?.toLowerCase().contains('beneficiario') ?? false)
            ? 'beneficiario'
            : 'asegurado';

    // ── 3. Sexo y Edad ─────────────────────────────────────────────────────
    final sexoStr = _extraerCampo(
      texto,
      RegExp(r'Sexo[:\s]+(FEMENINO|MASCULINO)', caseSensitive: false),
    );
    final sexo = (sexoStr != null && sexoStr.toLowerCase().contains('fem'))
        ? 'femenino'
        : (infoMatricula?.sexo ?? 'masculino');

    final edadStr = _extraerCampo(
      texto,
      RegExp(r'Edad[:\s]+(\d+)', caseSensitive: false),
    );
    final edad = edadStr != null ? int.tryParse(edadStr) : null;

    // ── 4. Regional y Empresa ──────────────────────────────────────────────
    final regional = _extraerCampo(
          texto,
          RegExp(
            r'Regional[:\s]+([A-ZÁÉÍÓÚÑ\s]+?)(?=\n|Matricula|Nombre|Empresa|$)',
            caseSensitive: false,
          ),
        ) ??
        'SANTA CRUZ';

    final empresa = _extraerCampo(
      texto,
      RegExp(
        r'Empresa[:\s]+([A-ZÁÉÍÓÚÑ0-9\s\.\-]+?)(?=\n|Nombre Hospital|Hospital|EN CASO|$)',
        caseSensitive: false,
      ),
    );

    // ── 5. Datos del Titular (si es Beneficiario) ──────────────────────────
    String? matriculaTitular;
    String? nombreTitular;
    String? paternoTitular;
    String? maternoTitular;
    String? nombresTitular;
    DateTime? fechaNacTitular;
    String? sexoTitular;

    if (tipoPaciente == 'beneficiario') {
      matriculaTitular = _extraerCampo(
        texto,
        RegExp(
          r'Matricula\s+Titular[:\s]+([12]\d{7}[A-Z]{3,4}\d?)',
          caseSensitive: false,
        ),
      );

      final infoTit = matriculaTitular != null
          ? decodificarMatricula(matriculaTitular)
          : null;
      nombreTitular =
          _extraerNombreTitular(texto, iniciales: infoTit?.iniciales);

      if (matriculaTitular != null) {
        if (infoTit != null) {
          fechaNacTitular = infoTit.fechaNacimiento;
          sexoTitular = infoTit.sexo;

          if (nombreTitular != null && nombreTitular.isNotEmpty) {
            final desglose = desglosarNombre(
              nombreTitular,
              iniciales: infoTit.iniciales,
            );
            paternoTitular = desglose.apellidoPaterno;
            maternoTitular = desglose.apellidoMaterno;
            nombresTitular = desglose.nombres;
          }
        }
      }
    }

    // ── 6. Carnet y Fecha de Nacimiento ────────────────────────────────────
    final carnet = _extraerCampo(
      texto,
      RegExp(
        r'Carnet(?:\s+de\s+Identidad)?[:\s]+([0-9A-Za-z\-]+)',
        caseSensitive: false,
      ),
    );

    final fechaNacStr = _extraerCampo(
      texto,
      RegExp(
        r'Fecha\s+de\s+Nacimiento[:\s]+(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4})',
        caseSensitive: false,
      ),
    );
    var fechaNac = infoMatricula?.fechaNacimiento;
    if (fechaNac == null && fechaNacStr != null) {
      fechaNac = _parsearFecha(fechaNacStr);
    }

    // ── 7. Causa, Médico Tratante y Responsable de Pago ────────────────────
    final causaStr = _extraerCampo(
      texto,
      RegExp(
        r'Hospitalizado\s+por[:\s]+([A-ZÁÉÍÓÚÑ\s]+?)(?=\n|Medico|Médico|$)',
        caseSensitive: false,
      ),
    );
    final hospitalizadoPor = _normalizarCausa(causaStr);

    final medico = _extraerCampo(
      texto,
      RegExp(
        r'Med(?:ico|íco)\s+que\s+interna[:\s]+([A-ZÁÉÍÓÚÑ\s]+?)(?=\n|Fecha|Servicio|Cama|$)',
        caseSensitive: false,
      ),
    );

    final responsablePago = _extraerCampo(
          texto,
          RegExp(
            r'Responsable\s+de\s+Pago[:\s]+([A-Z0-9\s]+?)(?=\n|Hospitalizado|$)',
            caseSensitive: false,
          ),
        ) ??
        'CPS';

    // ── 8. Fecha de Ingreso, Servicio y Cama ───────────────────────────────
    final fechaHoraIngresoStr = _extraerCampo(
      texto,
      RegExp(
        r'Fecha\s+y\s+Hora\s+de\s+Ingreso[:\s]+(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}\s+\d{1,2}:\d{2})',
        caseSensitive: false,
      ),
    );
    final fechaIngreso = fechaHoraIngresoStr != null
        ? _parsearFechaHora(fechaHoraIngresoStr)
        : DateTime.now();

    final servicio = _extraerCampo(
      texto,
      RegExp(
        r'Servicio[:\s]+([A-ZÁÉÍÓÚÑ\s0-9]+?)(?=\n|Cama|Servicio quien|$)',
        caseSensitive: false,
      ),
    );

    final servicioQuienAtendera = _extraerCampo(
      texto,
      RegExp(
        r'Servicio\s+quien\s+atender[aá][:\s]+([A-ZÁÉÍÓÚÑ\s0-9]+?)(?=\n|Diagnostico|Diagnóstico|$)',
        caseSensitive: false,
      ),
    );

    final camaCodigoRaw = _extraerCampo(
      texto,
      RegExp(
        r'(?:Cama|Carna|Camo|Cam\s*a|Cam)[\s\:\.\-]*([A-Z0-9\-\s/]+?)(?=\n|Servicio|Diagn|$)',
        caseSensitive: false,
      ),
    );

    String? camaCodigo;
    if (camaCodigoRaw != null) {
      var cleaned = camaCodigoRaw.replaceAll(RegExp(r'\s+'), '');
      cleaned = cleaned.replaceFirst(RegExp('^[A-Z]*0*'), '');
      if (cleaned.isNotEmpty) {
        camaCodigo = cleaned;
      }
    }

    // ── 9. Diagnóstico y Tipo de Ingreso ───────────────────────────────────
    final diagnostico = _extraerCampo(
      texto,
      RegExp(
        r'Diagn[oó]stico(?:\s+de\s+Ingreso)?[:\s]+([A-ZÁÉÍÓÚÑ0-9\s\.\-]+?)(?=\n|Tipo Ingreso|$)',
        caseSensitive: false,
      ),
    );

    final tipoIngresoStr = _extraerCampo(
      texto,
      RegExp(
        r'Tipo\s+Ingreso[:\s]+([A-ZÁÉÍÓÚÑ\s]+?)(?=\n|$)',
        caseSensitive: false,
      ),
    );
    final tipoIngreso =
        (tipoIngresoStr?.toLowerCase().contains('urgencia') ?? false)
            ? 'urgencia'
            : 'programado';

    return DatosIngresoHC2(
      apellidoPaterno: nombresYApellidos.apellidoPaterno,
      apellidoMaterno: nombresYApellidos.apellidoMaterno,
      nombres: nombresYApellidos.nombres,
      matricula: matriculaPaciente ?? infoMatricula?.matricula ?? '',
      fechaNacimiento: fechaNac,
      sexo: sexo,
      edadAprox: edad,
      tipoPaciente: tipoPaciente,
      regional: regional.trim(),
      empresaAseguradora: empresa?.trim(),
      carnetIdentidad:
          (carnet != null && carnet.length >= 4) ? carnet.trim() : null,
      matriculaTitular: matriculaTitular,
      nombreTitular: nombreTitular?.trim(),
      apellidoPaternoTitular: paternoTitular,
      apellidoMaternoTitular: maternoTitular,
      nombresTitular: nombresTitular,
      fechaNacimientoTitular: fechaNacTitular,
      sexoTitular: sexoTitular,
      empresaTitular: empresa?.trim(),
      fechaIngreso: fechaIngreso,
      servicio: servicio?.trim(),
      camaCodigo: camaCodigo?.trim(),
      servicioQuienAtendera: servicioQuienAtendera?.trim(),
      hospitalizadoPor: hospitalizadoPor,
      medicoTratante: medico?.trim(),
      diagnosticoInicial: diagnostico?.trim(),
      tipoIngreso: tipoIngreso,
      responsablePago: responsablePago.trim(),
    );
  }

  // ── Métodos Auxiliares ────────────────────────────────────────────────────

  String? _extraerCampo(String texto, RegExp regex) {
    final match = regex.firstMatch(texto);
    if (match != null && match.groupCount >= 1) {
      final val = match.group(1)?.trim();
      if (val != null && val.isNotEmpty && val != '.') {
        return val;
      }
    }
    return null;
  }

  String? _extraerMatriculaPaciente(String texto) {
    // Buscar primero "Matricula: XXXXX"
    final matchMat = RegExp(
      r'(?:Matricula|Matrícula)(?!\s+Titular)[:\s]+([12]\d{7}[A-Z]{3,4}\d?)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (matchMat != null) return matchMat.group(1);

    // O bien la primera matrícula CPS que aparezca en el texto
    final matchGen = _regexMatricula.firstMatch(texto);
    return matchGen?.group(0);
  }

  static final Set<String> _palabrasReservadasFormulario = {
    'CAJA',
    'PETROLERA',
    'DE',
    'SALUD',
    'HOSPITAL',
    'SANTA',
    'CRUZ',
    'FORMULARIO',
    'INGRESO',
    'HOSPITALARIO',
    'FECHA',
    'INTERNACION',
    'INTERNACIÓN',
    'IMPRESION',
    'IMPRESIÓN',
    'NHC2',
    'USUARIO',
    'VIGENTE',
    'APELLIDO',
    'PATERNO',
    'MATERNO',
    'NOMBRE',
    'NOMBRES',
    'MATRICULA',
    'MATRÍCULA',
    'EDAD',
    'SEXO',
    'FEMENINO',
    'MASCULINO',
    'TIPO',
    'PAC',
    'PACIENTE',
    'ASEGURADO',
    'BENEFICIARIO',
    'REGIONAL',
    'EMPRESA',
    'TITULAR',
    'CARNET',
    'IDENTIDAD',
    'ENFERMEDAD',
    'URGENCIA',
    'SERVICIO',
    'CAMA',
  };

  DesgloseNombre _extraerNombresYApellidos(
    String texto, {
    String? matriculaConocida,
    String? inicialesConocidas,
  }) {
    // Resolver matrícula e iniciales CPS
    final matPac = matriculaConocida ?? _extraerMatriculaPaciente(texto);
    final infoMat = matPac != null ? decodificarMatricula(matPac) : null;
    final iniciales = (inicialesConocidas ?? infoMat?.iniciales)
        ?.replaceAll(RegExp('[^A-Z]'), '');

    // ── Nivel 1: Etiquetas explícitas en la misma línea ───────────────────────
    // ej: "Apellido Paterno: DAVILA" o "Apellido Paterno DAVILA"
    final patExp = _extraerValorEtiqueta(texto, r'Apellido\s+Paterno');
    final matExp = _extraerValorEtiqueta(texto, r'Apellido\s+Materno');
    final nomExp = _extraerValorEtiqueta(texto, r'Nombre\(?s?\)?');

    if (patExp != null && nomExp != null) {
      return DesgloseNombre(
        apellidoPaterno: patExp.toUpperCase(),
        apellidoMaterno: matExp?.toUpperCase(),
        nombres: nomExp.toUpperCase(),
      );
    }

    // ── Nivel 2: Emparejamiento vertical por adyacencia de línea ─────────────
    // Bloques verticales típicos de ML Kit cuando se fotografían columnas:
    // [DAVILA]\nApellido Paterno  o  Apellido Paterno\n[DAVILA]
    final desgloseVertical = _extraerNombresVerticales(texto);
    if (desgloseVertical != null) {
      return desgloseVertical;
    }

    // ── Nivel 3: Misma línea que la matrícula o línea inmediatamente previa ──
    final lineas = texto.split('\n');
    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i].trim();
      final matchMat = _regexMatricula.firstMatch(l);
      if (matchMat != null && !l.toLowerCase().contains('titular')) {
        final antesMatricula = l.substring(0, matchMat.start).trim();
        final limpio = _limpiarPrefijosNombre(antesMatricula);

        if (limpio.isNotEmpty) {
          final palabras =
              limpio.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
          if (palabras.length >= 2) {
            return desglosarNombre(
              limpio,
              iniciales: matchMat.group(4) ?? iniciales,
            );
          }
        }

        // Si la matrícula está sola en la línea, comprobar la línea inmediatamente anterior
        if (i > 0) {
          final lineaAnterior = _limpiarPrefijosNombre(lineas[i - 1].trim());
          if (_esLineaCandidataNombre(lineaAnterior)) {
            return desglosarNombre(
              lineaAnterior,
              iniciales: matchMat.group(4) ?? iniciales,
            );
          }
        }
      }
    }

    // ── Nivel 4: Línea inmediatamente previa a la fila de etiquetas ──────────
    // En el HC-2 original impreso:
    // DAVILA          SUSANO          ELIZABETH          19525414DSE
    // Apellido Paterno   Apellido Materno   Nombre(s)          Matricula
    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i].toLowerCase();
      if (l.contains('apellido paterno') &&
          (l.contains('apellido materno') || l.contains('nombre'))) {
        if (i > 0) {
          final lineaAnterior = _limpiarPrefijosNombre(lineas[i - 1].trim());
          if (_esLineaCandidataNombre(lineaAnterior)) {
            return desglosarNombre(lineaAnterior, iniciales: iniciales);
          }
        }
      }
    }

    // ── Nivel 5: Anclaje estricto por iniciales institucionales CPS ──────────
    // Cuando el OCR fragmentó los textos en palabras aisladas en diferentes bloques,
    // usamos las iniciales de la matrícula (ej. "DSE" -> D=Davila, S=Susano, E=Elizabeth)
    if (iniciales != null && iniciales.length >= 2) {
      final desglosePorIniciales = _extraerPorInicialesAnchor(texto, iniciales);
      if (desglosePorIniciales != null) {
        return desglosePorIniciales;
      }
    }

    return const DesgloseNombre(apellidoPaterno: '', nombres: '');
  }

  String? _extraerValorEtiqueta(String texto, String patron) {
    final regex = RegExp(
      '$patron[:\\s]+([A-ZÁÉÍÓÚÑ\\s]+?)(?=\\n|Apellido|Nombre|Matricula|Matrícula|Edad|Sexo|Tipo|\$)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(texto);
    if (match != null) {
      final val = match.group(1)?.trim();
      if (val != null && val.isNotEmpty) {
        final upper = val.toUpperCase();
        if (!_palabrasReservadasFormulario.contains(upper)) {
          return upper;
        }
      }
    }
    return null;
  }

  DesgloseNombre? _extraerNombresVerticales(String texto) {
    final lineas = texto.split('\n').map((l) => l.trim()).toList();

    String? paterno;
    String? materno;
    String? nombres;

    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i].toLowerCase();

      // Buscar "Apellido Paterno" aislado
      if (l.contains('apellido paterno') &&
          !l.contains('materno') &&
          !l.contains('nombre')) {
        if (i > 0 && _esPalabraCandidataSimple(lineas[i - 1])) {
          paterno ??= lineas[i - 1].toUpperCase();
        } else if (i + 1 < lineas.length &&
            _esPalabraCandidataSimple(lineas[i + 1])) {
          paterno ??= lineas[i + 1].toUpperCase();
        }
      }

      // Buscar "Apellido Materno" aislado
      if (l.contains('apellido materno') &&
          !l.contains('paterno') &&
          !l.contains('nombre')) {
        if (i > 0 && _esPalabraCandidataSimple(lineas[i - 1])) {
          materno ??= lineas[i - 1].toUpperCase();
        } else if (i + 1 < lineas.length &&
            _esPalabraCandidataSimple(lineas[i + 1])) {
          materno ??= lineas[i + 1].toUpperCase();
        }
      }

      // Buscar "Nombre(s)" o "Nombre" aislado (sin hospital ni titular)
      if ((l == 'nombre(s)' || l == 'nombres' || l == 'nombre') &&
          !l.contains('hospital') &&
          !l.contains('titular')) {
        if (i > 0 && _esPalabraCandidataNombre(lineas[i - 1])) {
          nombres ??= lineas[i - 1].toUpperCase();
        } else if (i + 1 < lineas.length &&
            _esPalabraCandidataNombre(lineas[i + 1])) {
          nombres ??= lineas[i + 1].toUpperCase();
        }
      }
    }

    if (paterno != null && nombres != null) {
      return DesgloseNombre(
        apellidoPaterno: paterno,
        apellidoMaterno: materno,
        nombres: nombres,
      );
    }
    return null;
  }

  bool _esPalabraCandidataSimple(String linea) {
    final trim = linea.trim();
    if (trim.isEmpty) return false;
    final palabras =
        trim.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty || palabras.length > 2) return false;
    for (final p in palabras) {
      if (_palabrasReservadasFormulario.contains(p.toUpperCase())) {
        return false;
      }
      if (!RegExp(r'^[A-ZÁÉÍÓÚÑa-záéíóúñ]+$').hasMatch(p)) {
        return false;
      }
    }
    return true;
  }

  bool _esPalabraCandidataNombre(String linea) {
    final trim = linea.trim();
    if (trim.isEmpty) return false;
    final palabras =
        trim.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty || palabras.length > 3) return false;
    for (final p in palabras) {
      if (_palabrasReservadasFormulario.contains(p.toUpperCase())) {
        return false;
      }
      if (!RegExp(r'^[A-ZÁÉÍÓÚÑa-záéíóúñ]+$').hasMatch(p)) {
        return false;
      }
    }
    return true;
  }

  bool _esLineaCandidataNombre(String linea) {
    final trim = linea.trim();
    if (trim.isEmpty) return false;
    final palabras =
        trim.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.length < 2 || palabras.length > 5) return false;
    for (final p in palabras) {
      if (_palabrasReservadasFormulario.contains(p.toUpperCase())) {
        return false;
      }
      if (!RegExp(r'^[A-ZÁÉÍÓÚÑa-záéíóúñ]+$').hasMatch(p)) {
        return false;
      }
    }
    return true;
  }

  String _limpiarPrefijosNombre(String str) {
    return str
        .replaceAll(RegExp(r'VIGENTE\s*[-:]?', caseSensitive: false), '')
        .replaceAll(RegExp('FORMULARIO.*', caseSensitive: false), '')
        .replaceAll(RegExp('CAJA.*', caseSensitive: false), '')
        .trim();
  }

  DesgloseNombre? _extraerPorInicialesAnchor(String texto, String iniciales) {
    if (iniciales.length < 2) return null;

    final corteClinico = texto.indexOf('EN CASO DE URGENCIA');
    final seccionPersonal =
        corteClinico != -1 ? texto.substring(0, corteClinico) : texto;

    final palabras = seccionPersonal
        .split(RegExp(r'[\s\n\r,.:;/\-]+'))
        .map((p) => p.trim().toUpperCase())
        .where((p) => p.length >= 2 && RegExp(r'^[A-ZÁÉÍÓÚÑ]+$').hasMatch(p))
        .where((p) => !_palabrasReservadasFormulario.contains(p))
        .toList();

    final pInit = iniciales[0];
    final mInit = iniciales.length >= 3 ? iniciales[1] : null;
    final nInit = iniciales.length >= 3 ? iniciales[2] : iniciales[1];

    for (var i = 0; i < palabras.length; i++) {
      if (palabras[i].startsWith(pInit)) {
        final candPaterno = palabras[i];

        if (mInit != null &&
            i + 1 < palabras.length &&
            palabras[i + 1].startsWith(mInit)) {
          final candMaterno = palabras[i + 1];

          if (i + 2 < palabras.length && palabras[i + 2].startsWith(nInit)) {
            final candNombre1 = palabras[i + 2];
            final nombres = <String>[candNombre1];
            var j = i + 3;
            while (j < palabras.length &&
                !_palabrasReservadasFormulario.contains(palabras[j]) &&
                j < i + 5) {
              nombres.add(palabras[j]);
              j++;
            }
            return DesgloseNombre(
              apellidoPaterno: candPaterno,
              apellidoMaterno: candMaterno,
              nombres: nombres.join(' '),
            );
          }
        } else if (i + 1 < palabras.length &&
            palabras[i + 1].startsWith(nInit)) {
          final candNombre1 = palabras[i + 1];
          final nombres = <String>[candNombre1];
          var j = i + 2;
          while (j < palabras.length &&
              !_palabrasReservadasFormulario.contains(palabras[j]) &&
              j < i + 4) {
            nombres.add(palabras[j]);
            j++;
          }
          return DesgloseNombre(
            apellidoPaterno: candPaterno,
            nombres: nombres.join(' '),
          );
        }
      }
    }
    return null;
  }

  String? _extraerNombreTitular(String texto, {String? iniciales}) {
    // 1. Etiqueta horizontal directa
    final match = RegExp(
      r'Nombre\s+Titular[:\s]+([A-ZÁÉÍÓÚÑ\s]+?)(?=\n|Nombre Hospital|Hospital|Empresa|Regional|$)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null && match.group(1) != null) {
      final val = match.group(1)!.trim();
      if (val.isNotEmpty && val != '.') {
        final palabras =
            val.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        if (palabras.any(
          (p) => !_palabrasReservadasFormulario.contains(p.toUpperCase()),
        )) {
          return val;
        }
      }
    }

    // 2. Etiqueta vertical "Nombre Titular"
    final lineas = texto.split('\n').map((l) => l.trim()).toList();
    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i].toLowerCase();
      if (l == 'nombre titular' || l == 'nombre titular:') {
        if (i + 1 < lineas.length) {
          final siguiente = lineas[i + 1];
          if (_esLineaCandidataNombre(siguiente)) {
            return siguiente;
          }
        }
      }
    }

    return null;
  }

  DateTime? _parsearFecha(String fechaStr) {
    final partes = fechaStr.split(RegExp(r'[\/\-]'));
    if (partes.length == 3) {
      final dia = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final anho = int.tryParse(partes[2]);
      if (dia != null && mes != null && anho != null) {
        return DateTime.utc(anho, mes, dia);
      }
    }
    return null;
  }

  DateTime? _parsearFechaHora(String fechaHoraStr) {
    try {
      final partes = fechaHoraStr.trim().split(RegExp(r'\s+'));
      if (partes.length >= 2) {
        final fecha = _parsearFecha(partes[0]);
        final horaPartes = partes[1].split(':');
        if (fecha != null && horaPartes.length >= 2) {
          final h = int.tryParse(horaPartes[0]) ?? 0;
          final m = int.tryParse(horaPartes[1]) ?? 0;
          return DateTime.utc(fecha.year, fecha.month, fecha.day, h, m);
        }
      }
      return _parsearFecha(fechaHoraStr);
    } on Exception {
      return null;
    }
  }

  String _normalizarCausa(String? causa) {
    if (causa == null) return 'enfermedad';
    final c = causa.toLowerCase();
    if (c.contains('accidente') && c.contains('trabajo')) {
      return 'accidente_trabajo';
    }
    if (c.contains('accidente') && c.contains('comun')) {
      return 'accidente_comun';
    }
    if (c.contains('maternidad')) return 'maternidad';
    if (c.contains('emergencia')) return 'emergencia';
    return 'enfermedad';
  }
}
