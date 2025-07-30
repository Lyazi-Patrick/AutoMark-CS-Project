// This is a Dart file for a service that parses files like PDF and DOCX 
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

class FileParseService {
  static Future<String> extractTextFromFile(File file) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();

      if (ext == 'pdf') {
        return await _parsePDF(file);
      } else if (ext == 'docx') {
        return await _parseDocx(file);
      } else {
        throw Exception("Unsupported file type: .$ext");
      }
    } catch (e) {
      debugPrint("File parse error: $e");
      return "Error parsing file: $e";
    }
  }

  static Future<String> _parsePDF(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final StringBuffer textBuffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      final extractedText = PdfTextExtractor(document).extractText(
        startPageIndex: i,
        endPageIndex: i,
      );
      textBuffer.writeln(extractedText);
    }

    document.dispose();
    return textBuffer.toString().trim();
  }

  static Future<String> _parseDocx(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final contentFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('Invalid .docx file structure.'),
    );

    final xmlStr = utf8.decode(contentFile.content as List<int>);
    final document = XmlDocument.parse(xmlStr);

    final buffer = StringBuffer();
    document.findAllElements('w:t').forEach((element) {
      buffer.write(element.text);
    });

    return buffer.toString().trim();
  }
}
