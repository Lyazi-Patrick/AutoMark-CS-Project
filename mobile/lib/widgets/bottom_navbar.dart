import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ocr_service.dart'; // NEW: Import OCRService

class AutoMarkBottomNav extends StatelessWidget {
  final int currentIndex;

  const AutoMarkBottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/scan');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/result');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/answer_key');
        break;
    }
  }

  void _triggerBatchScan(BuildContext context) async {
    final picker = ImagePicker();

    try {
      final pickedImages = await picker.pickMultiImage(imageQuality: 80);

      if (pickedImages == null || pickedImages.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No images selected')));
        return;
      }

      String combinedText = '';
      // NEW: Use OCRService for text extraction
      final ocrService = OCRService();
      for (var pickedFile in pickedImages) {
        final extracted = await ocrService.extractTextFromImage(
          File(pickedFile.path),
        ); // NEW
        combinedText += extracted + '\n\n'; // NEW
      }

      if (context.mounted) {
        Navigator.pushNamed(context, '/scan', arguments: combinedText);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Batch scanning failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onTap(context, index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Results'),
        BottomNavigationBarItem(icon: Icon(Icons.key), label: 'Answer Key'),
      ],
    );
  }
}
