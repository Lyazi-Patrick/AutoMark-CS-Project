import 'dart:io';
import 'package:pdf_text/pdf_text.dart';

class PDFService {
  Future<String> extractTextFromPdf(File file) async {
    try {
      final pdfDoc = await PDFDoc.fromFile(file);
      final text = await pdfDoc.text;
      return text;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }
}