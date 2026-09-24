import 'package:app_movil/features/internaciones/domain/entities/datos_ingreso_hc2.dart';
import 'package:app_movil/features/internaciones/domain/services/hc2_parser_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Servicio de reconocimiento óptico de caracteres (OCR) sobre imágenes del
/// formulario HC-2 de la Caja Petrolera de Salud.
class OcrService {
  const OcrService({
    HC2ParserService parserService = const HC2ParserService(),
  }) : _parserService = parserService;

  final HC2ParserService _parserService;

  /// Procesa la imagen del archivo local mediante Google ML Kit y parsea los
  /// datos del formulario HC-2.
  Future<({String textoCrudo, DatosIngresoHC2 datos})> procesarImagenHC2(
    String rutaArchivo,
  ) async {
    final inputImage = InputImage.fromFilePath(rutaArchivo);
    final textRecognizer = TextRecognizer();

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final textoCrudo = recognizedText.text;
      final datos = _parserService.parsear(textoCrudo);

      return (textoCrudo: textoCrudo, datos: datos);
    } finally {
      await textRecognizer.close();
    }
  }

  /// Parsea directamente un texto plano reconocido (útil para pruebas unitarias).
  DatosIngresoHC2 parsearTexto(String textoCrudo) {
    return _parserService.parsear(textoCrudo);
  }
}
