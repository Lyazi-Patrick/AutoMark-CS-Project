import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';
import '../services/ocr_service.dart'; // NEW: Import OCRService

class UploadScriptScreen extends StatefulWidget {
  const UploadScriptScreen({super.key});

  @override
  State<UploadScriptScreen> createState() => _UploadScriptScreenState();
}

class _UploadScriptScreenState extends State<UploadScriptScreen> {
  final List<File> _imageFiles = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _extractedText = '';
  bool _isLoading = false;

  Future<void> _pickImagesFromGallery() async {
    if (_nameController.text.trim().isEmpty ||
        _numberController.text.trim().isEmpty) {
      _showSnackBar(
        "Please enter both name and student number before uploading.",
        isError: true,
      );
      return;
    }
    try {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _imageFiles.clear();
          _imageFiles.addAll(pickedFiles.map((f) => File(f.path)));
          _extractedText = '';
          _isLoading = true;
        });
        await _performBatchOCR(_imageFiles);
      }
    } catch (e) {
      _showSnackBar("Gallery picking failed: $e", isError: true);
    }
  }

  Future<void> _pickImagesFromCamera() async {
    if (_nameController.text.trim().isEmpty ||
        _numberController.text.trim().isEmpty) {
      _showSnackBar(
        "Please enter both name and student number before taking a photo.",
        isError: true,
      );
      return;
    }
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(File(pickedFile.path));
          _extractedText = '';
          _isLoading = true;
        });
        await _performBatchOCR(_imageFiles);
      }
    } catch (e) {
      _showSnackBar("Camera failed: $e", isError: true);
    }
  }

  Future<void> _performBatchOCR(List<File> imageFiles) async {
    // NEW: Use OCRService for text extraction
    final ocrService = OCRService();
    String fullText = '';
    for (final file in imageFiles) {
      final extracted = await ocrService.extractTextFromImage(file); // NEW
      fullText += extracted + '\n'; // NEW
    }
    await _saveToFirestore(fullText);
  }

  Future<void> _saveToFirestore(String text) async {
    final name =
        _nameController.text.trim().isEmpty
            ? 'Student  [36m${DateTime.now().millisecondsSinceEpoch} [0m'
            : _nameController.text.trim();
    final number = _numberController.text.trim();

    await FirebaseFirestore.instance.collection('scripts').add({
      'name': name,
      'number': number,
      'ocrText': text,
      'status': 'unmarked',
      'timestamp': Timestamp.now(),
    });

    setState(() {
      _extractedText = text;
      _isLoading = false;
    });

    _showSnackBar("✅ Script saved as UNMARKED successfully!");
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearImages() {
    setState(() {
      _imageFiles.clear();
      _extractedText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("UPLOAD SCRIPT"), centerTitle: true),
      drawer: const CustomDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/bluetick.png', height: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'AutoMark',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Student Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Display images
              if (_imageFiles.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageFiles.length,
                    itemBuilder:
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Image.file(_imageFiles[index], height: 100),
                        ),
                  ),
                )
              else
                const Icon(Icons.image, size: 100, color: Colors.grey),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                    onPressed: _isLoading ? null : _pickImagesFromGallery,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                    onPressed: _isLoading ? null : _pickImagesFromCamera,
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Divider(),
              const Text(
                'Extracted Text:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      _extractedText.isEmpty
                          ? const Text('No text extracted yet.')
                          : Text(_extractedText),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 1),
    );
  }
}
