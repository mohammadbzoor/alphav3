// ignore: depend_on_referenced_packages
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> extractText(
    String imagePath,
  ) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      return recognizedText.text.trim();
    } catch (error) {
      throw Exception(
        'Failed to read the receipt: $error',
      );
    }
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
