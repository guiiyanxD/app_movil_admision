import 'package:app_movil/features/internaciones/domain/services/hc2_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = HC2ParserService();

  group('HC2ParserService - Algoritmo de Matrícula CPS', () {
    test('decodifica matrícula masculina correctamente', () {
      // 19500504ZBH: Año 1950, Mes 05 (Mayo), Día 04, Iniciales ZBH
      final info = parser.decodificarMatricula('19500504ZBH');
      expect(info, isNotNull);
      expect(info!.matricula, equals('19500504ZBH'));
      expect(info.sexo, equals('masculino'));
      expect(info.fechaNacimiento, equals(DateTime.utc(1950, 5, 4)));
      expect(info.iniciales, equals('ZBH'));
    });

    test('decodifica matrícula femenina correctamente (mes + 50)', () {
      // 19525414DSE: Año 1952, Mes 54 (Abril = 54 - 50 = 4), Día 14, Iniciales DSE
      final info = parser.decodificarMatricula('19525414DSE');
      expect(info, isNotNull);
      expect(info!.matricula, equals('19525414DSE'));
      expect(info.sexo, equals('femenino'));
      expect(info.fechaNacimiento, equals(DateTime.utc(1952, 4, 14)));
      expect(info.iniciales, equals('DSE'));
    });

    test('decodifica matrícula femenina de octubre (mes 60 = 10)', () {
      // 19596005SRJ: Año 1959, Mes 60 (Octubre = 60 - 50 = 10), Día 05, Iniciales SRJ
      final info = parser.decodificarMatricula('19596005SRJ');
      expect(info, isNotNull);
      expect(info!.sexo, equals('femenino'));
      expect(info.fechaNacimiento, equals(DateTime.utc(1959, 10, 5)));
      expect(info.iniciales, equals('SRJ'));
    });

    test('retorna null para matrícula con formato inválido', () {
      expect(parser.decodificarMatricula('INVALIDA'), isNull);
      expect(parser.decodificarMatricula('19809901ABC'), isNull); // mes 99
    });
  });

  group('HC2ParserService - Desglose de Nombres apoyado en Iniciales', () {
    test('desglosa 3 palabras en Paterno, Materno y Nombres', () {
      final desglose = parser.desglosarNombre(
        'ZABALA BURGOS HUGO',
        iniciales: 'ZBH',
      );
      expect(desglose.apellidoPaterno, equals('ZABALA'));
      expect(desglose.apellidoMaterno, equals('BURGOS'));
      expect(desglose.nombres, equals('HUGO'));
    });

    test('desglosa 4 palabras con 2 nombres de pila', () {
      final desglose = parser.desglosarNombre(
        'SUAREZ RUIZ JENNY CRISTINA',
        iniciales: 'SRJ',
      );
      expect(desglose.apellidoPaterno, equals('SUAREZ'));
      expect(desglose.apellidoMaterno, equals('RUIZ'));
      expect(desglose.nombres, equals('JENNY CRISTINA'));
    });

    test('desglosa paciente con un solo apellido', () {
      final desglose = parser.desglosarNombre('DAVILA ELIZABETH');
      expect(desglose.apellidoPaterno, equals('DAVILA'));
      expect(desglose.apellidoMaterno, isNull);
      expect(desglose.nombres, equals('ELIZABETH'));
    });
  });

  group('HC2ParserService - Parseo de Formularios Reales (Muestras Fotográficas)', () {
    test('extrae datos completos de Formulario 1 (Beneficiario con Titular)', () {
      const textoOCR = '''
Caja Petrolera de Salud          FORMULARIO DE INGRESO HOSPITALARIO           Impresión: 15/09/2026 23:12
Form. HC-2                             FECHA INTERNACION 15/09/2026                         NHC2: 004285
Usuario: msjustiniano
VIGENTE -
DAVILA SUSANO ELIZABETH 19525414DSE
Apellido Paterno Apellido Materno Nombre(s) Matricula
Edad: 74-5 Sexo: FEMENINO Tipo.Pac: Beneficiario Regional: SANTA CRUZ
Matricula Titular: 19500504ZBH Nombre Titular: ZABALA BURGOS HUGO
Empresa: GESTORA PUBLICA DE LA SEGURIDA Nombre Hospital: HOSPITAL SANTA CRUZ
EN CASO DE URGENCIA LLAMAR A:
Nombre:
Dirección: Teléfono:
Carnet de Identidad: Fecha de Nacimiento: 14/04/1952 Responsable de Pago: CPS
Hospitalizado por: ENFERMEDAD Medico que interna: QUISPE MEDRANO LUCY
Fecha y Hora de Ingreso: 15/09/2026 23:10 Servicio: UROLOGIA Cama: U0216-B
Servicio quien atendera: UROLOGIA
Diagnostico de Ingreso: SX ICTERICO Tipo Ingreso: NORMAL
''';

      final datos = parser.parsear(textoOCR);

      // Paciente
      expect(datos.apellidoPaterno, equals('DAVILA'));
      expect(datos.apellidoMaterno, equals('SUSANO'));
      expect(datos.nombres, equals('ELIZABETH'));
      expect(datos.matricula, equals('19525414DSE'));
      expect(datos.sexo, equals('femenino'));
      expect(datos.tipoPaciente, equals('beneficiario'));
      expect(datos.esBeneficiario, isTrue);
      expect(datos.regional, equals('SANTA CRUZ'));
      expect(datos.empresaAseguradora, equals('GESTORA PUBLICA DE LA SEGURIDA'));

      // Titular
      expect(datos.matriculaTitular, equals('19500504ZBH'));
      expect(datos.nombreTitular, equals('ZABALA BURGOS HUGO'));
      expect(datos.apellidoPaternoTitular, equals('ZABALA'));
      expect(datos.apellidoMaternoTitular, equals('BURGOS'));
      expect(datos.nombresTitular, equals('HUGO'));
      expect(datos.sexoTitular, equals('masculino'));
      expect(datos.fechaNacimientoTitular, equals(DateTime.utc(1950, 5, 4)));

      // Internación
      expect(datos.camaCodigo, equals('216-B'));
      expect(datos.servicio, equals('UROLOGIA'));
      expect(datos.medicoTratante, equals('QUISPE MEDRANO LUCY'));
      expect(datos.diagnosticoInicial, equals('SX ICTERICO'));
      expect(datos.hospitalizadoPor, equals('enfermedad'));
      expect(datos.tipoIngreso, equals('programado')); // NORMAL -> programado
      expect(datos.responsablePago, equals('CPS'));
    });

    test('extrae datos completos de Formulario 2 (Asegurado Directo)', () {
      const textoOCR = '''
Caja Petrolera de Salud          FORMULARIO DE INGRESO HOSPITALARIO           Impresión: 15/09/2026 07:27
Form. HC-2                             FECHA INTERNACION 15/09/2026                         NHC2: 004206
Usuario: fmendez
VIGENTE -
SUAREZ RUIZ JENNY CRISTINA 19596005SRJ
Apellido Paterno Apellido Materno Nombre(s) Matricula
Edad: 66-11 Sexo: FEMENINO Tipo.Pac: Asegurado Regional: SANTA CRUZ
Empresa: GESTORA PUBLICA DE LA SEGURIDA Nombre Hospital: HOSPITAL SANTA CRUZ
EN CASO DE URGENCIA LLAMAR A:
Nombre: .
Dirección: . Teléfono: .
Carnet de Identidad: Fecha de Nacimiento: 05/10/1959 Responsable de Pago: CPS
Hospitalizado por: ENFERMEDAD Medico que interna: BARRERA ZULETA GILDA IRENE
Fecha y Hora de Ingreso: 15/09/2026 07:25 Servicio: QUIMIOTERAPIA Cama: QUI09
Servicio quien atendera: QUIMIOTERAPIA
Diagnostico de Ingreso: CA DE MAMA TTO QUIMIOTERAPIA Tipo Ingreso: NORMAL
''';

      final datos = parser.parsear(textoOCR);

      // Paciente
      expect(datos.apellidoPaterno, equals('SUAREZ'));
      expect(datos.apellidoMaterno, equals('RUIZ'));
      expect(datos.nombres, equals('JENNY CRISTINA'));
      expect(datos.matricula, equals('19596005SRJ'));
      expect(datos.sexo, equals('femenino'));
      expect(datos.tipoPaciente, equals('asegurado'));
      expect(datos.esBeneficiario, isFalse);
      expect(datos.matriculaTitular, isNull);

      // Internación
      expect(datos.camaCodigo, equals('9'));
      expect(datos.servicio, equals('QUIMIOTERAPIA'));
      expect(datos.medicoTratante, equals('BARRERA ZULETA GILDA IRENE'));
      expect(datos.diagnosticoInicial, equals('CA DE MAMA TTO QUIMIOTERAPIA'));
      expect(datos.hospitalizadoPor, equals('enfermedad'));
      expect(datos.tipoIngreso, equals('programado'));
    });
  });
}
