import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';

class UploadScriptScreen extends StatefulWidget {
  const UploadScriptScreen({super.key});

  @override
  State<UploadScriptScreen> createState() => _UploadScriptScreenState();
}

class _UploadScriptScreenState extends State<UploadScriptScreen> {
  final List<File> _imageFiles = [];
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _extractedText = '';
  bool _isLoading = false;

  Future<void> _pickImagesFromGallery() async {
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
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
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
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String fullText = '';

    for (final file in imageFiles) {
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await textRecognizer.processImage(inputImage);
      fullText += '${_formatExtractedText(recognizedText)}\n\n';
    }

    await textRecognizer.close();

    setState(() {
      _extractedText = _cleanBrokenLines(fullText);
      _isLoading = false;
    });
  }

  String _formatExtractedText(RecognizedText visionText) {
    final buffer = StringBuffer();
    for (TextBlock block in visionText.blocks) {
      for (TextLine line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln(); // Adds space between blocks
    }
    return buffer.toString();
  }

  String _cleanBrokenLines(String text) {
    return text.replaceAllMapped(RegExp(r'([a-z0-9,])\n([a-zA-Z])'), (m) {
      return '${m[1]} ${m[2]}';
    });
  }

  Future<void> _saveScript({bool goToMarking = false}) async {
    final name = _nameController.text.trim().isEmpty
        ? 'Student ${DateTime.now().millisecondsSinceEpoch}'
        : _nameController.text.trim();

    try {
      final docRef = await FirebaseFirestore.instance.collection('scripts').add({
        'name': name,
        'ocrText': _extractedText,
        'status': 'unmarked',
        'timestamp': Timestamp.now(),
      });

      _showSnackBar("✅ Script saved successfully!");

      if (goToMarking) {
        Navigator.pushNamed(
          context,
          '/mark_script',
          arguments: {
            'id': docRef.id,
            'name': name,
            'ocrText': _extractedText,
            'timestamp': Timestamp.now(),
          },
        );
      } else {
        _clearForm();
      }
    } catch (e) {
      _showSnackBar("❌ Failed to save: $e", isError: true);
    }
  }

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _imageFiles.clear();
      _extractedText = '';
    });
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
                  const Text('AutoMark', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

              if (_imageFiles.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageFiles.length,
                    itemBuilder: (context, index) => Padding(
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

              const Text('Extracted Text:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: _extractedText.isEmpty
                      ? const Text('No text extracted yet.')
                      : Text(_extractedText),
                ),

              if (_extractedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save_alt),
                              label: const Text("Save & New"),
                              onPressed: () => _saveScript(goToMarking: false),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.bolt),
                              label: const Text("Save & Mark"),
                              onPressed: () => _saveScript(goToMarking: true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 1),
    );
  }
}