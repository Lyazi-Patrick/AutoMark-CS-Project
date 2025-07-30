import 'dart:io';   // This is 
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OCRService {
  final ImagePicker _picker = ImagePicker();

  /// Prompts user to pick an image from camera or gallery
  Future<File?> pickImage({bool fromCamera = true}) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }

  /// Extracts text from the given image using Google ML Kit
  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close(); // Always close recognizer

      return recognizedText.text;
    } catch (e) {
      debugPrint("OCR Error: $e");
      rethrow;
    }
  }
}