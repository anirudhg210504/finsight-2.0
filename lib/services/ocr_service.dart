import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // 1. Create an instance of the TextRecognizer
  final TextRecognizer _textRecognizer;

  OcrService()
  // Initialize the TextRecognizer.
  // Use script: TextRecognitionScript.latin for English/European languages.
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> processImage(String imagePath) async {
    print('⏳ Processing image with ML Kit: $imagePath...');

    try {
      // 2. Create an InputImage object from the file path
      final inputImage = InputImage.fromFilePath(imagePath);

      // 3. Process the image
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // 4. Return the full text
      print('✅ ML Kit processing complete.');
      return recognizedText.text;

    } catch (e) {
      print('❌ Error processing image with ML Kit: $e');
      return "Error: $e";
    }
  }

  // 5. Add a dispose method to release resources
  void dispose() {
    _textRecognizer.close();
  }
}