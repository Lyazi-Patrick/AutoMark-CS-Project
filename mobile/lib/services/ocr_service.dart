// NEW: Import necessary packages for image handling and ML Kit Text Recognition
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// NEW: OCRService class to handle text extraction from images
class OCRService {
  // NEW: Extracts text from a given image file
  Future<String> extractTextFromImage(File imageFile) async {
    // NEW: Create an InputImage from the file
    final inputImage = InputImage.fromFile(imageFile);
    // NEW: Initialize the text recognizer
    final textRecognizer = TextRecognizer();
    // NEW: Process the image and extract recognized text
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    // NEW: Close the recognizer to free resources
    await textRecognizer.close();
    // NEW: Return the full recognized text
    return recognizedText.text;
  }
}
