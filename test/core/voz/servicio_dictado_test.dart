import 'package:app_movil/core/voz/servicio_dictado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? elegir(List<String> disponibles) =>
      ServicioDictadoSpeechToText.elegirLocaleEntre(disponibles);

  group('Selección de locale', () {
    test('prefiere es_BO cuando está instalada', () {
      expect(elegir(['en_US', 'es_ES', 'es_BO']), 'es_BO');
    });

    test('cae a es_419 cuando no hay es_BO', () {
      // Es el caso realista en Android: es_BO casi nunca está instalada.
      expect(elegir(['en_US', 'es_ES', 'es_419']), 'es_419');
    });

    test('respeta el orden de preferencia completo', () {
      expect(elegir(['es_ES', 'es_MX']), 'es_MX');
      expect(elegir(['es_ES', 'es_AR', 'es_MX']), 'es_MX');
      expect(elegir(['es_ES']), 'es_ES');
    });

    test('acepta identificadores con guion medio', () {
      // iOS y algunos motores de Android devuelven "es-419", no "es_419".
      expect(elegir(['en-US', 'es-419']), 'es-419');
    });

    test('toma cualquier variante de español antes que rendirse', () {
      expect(elegir(['en_US', 'es_CO']), 'es_CO');
    });

    test('devuelve null si no hay ninguna locale española', () {
      // Nunca se cae a inglés en silencio: un motor en inglés interpretando
      // números en español produce basura plausible, que es peor que no
      // funcionar. Sin locale española el dictado se deshabilita.
      expect(elegir(['en_US', 'pt_BR', 'fr_FR']), isNull);
      expect(elegir([]), isNull);
    });
  });
}
