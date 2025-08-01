import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../services/ai_service.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';
import '../screens/mark_script_screen.dart';

class UploadScriptScreen extends StatefulWidget {
  const UploadScriptScreen({super.key});

  @override
  State<UploadScriptScreen> createState() => _UploadScriptScreenState();
}

class _UploadScriptScreenState extends State<UploadScriptScreen> {
  final List<File> _imageFiles = [];
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
   final TextEditingController _studentNumberController = TextEditingController();

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
  Future<File> enhanceImage(File originalImage) async {
    final bytes = await originalImage.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return originalImage;

    // Apply enhancement
    decoded = img.adjustColor(decoded,
      brightness: 0.15, // Range: -1.0 to 1.0
      contrast: 0.25    // Range: -1.0 to 1.0
    );


    final enhancedBytes = Uint8List.fromList(img.encodeJpg(decoded));
    final tempDir = await getTemporaryDirectory();
    final enhancedFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_enhanced.jpg');
    await enhancedFile.writeAsBytes(enhancedBytes);
    return enhancedFile;
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

    try {
    for (final file in imageFiles) {
      final enhancedImage = await enhanceImage(file); // ⬅ Enhance before OCR
      final inputImage = InputImage.fromFile(enhancedImage);
      final recognizedText = await textRecognizer.processImage(inputImage);
      fullText += _formatExtractedText(recognizedText) + '\n';
    }
      await textRecognizer.close();

      // Use GPT to structure answers
      final aiService = AIService();
      Map<String, String> extractedAnswers = {};
      try{
        extractedAnswers = await aiService.extractAnswersFromText(fullText, useGroq: true);
      } catch (aiError){
        _showSnackBar("AI extraction failed:$aiError", isError: true);
        extractedAnswers = {};
      }
      setState(() {
       if(extractedAnswers.isNotEmpty){
        _extractedText = extractedAnswers.entries.map((e) => "${e.key}: ${e.value}").join('\n');
       }else{
        _extractedText = fullText;//fall back to raw ocr if AI Fails        
       }
       _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("OCR or AI extraction failed: $e", isError: true);
    }
  }

  String _formatExtractedText(RecognizedText visionText) {
    final buffer = StringBuffer();
    for (TextBlock block in visionText.blocks) {
      for (TextLine line in block.lines) {
        buffer.writeln(line.text);
      }
    }
    return buffer.toString();
  }

  Future<void> _saveScript({bool goToMarking = false}) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    _showSnackBar("User not logged in.", isError: true);
    return;
  }

   final name = _nameController.text.trim();
    final studentNumber = _studentNumberController.text.trim();

    if (name.isEmpty && studentNumber.isEmpty) {
      _showSnackBar("Please provide either the student name or student number.", isError: true);
      return;
    }

    final String finalName = name.isNotEmpty ? name : 'Unnamed Student';

  try {
    final docRef = await FirebaseFirestore.instance.collection('scripts').add({
      'name': finalName,
      'studentNumber':studentNumber,
      'ocrText': _extractedText,
      'status': 'unmarked',
      'timestamp': Timestamp.now(),
      'userId': currentUser.uid,   
    });

    _showSnackBar("Script saved successfully!");

    if (goToMarking) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MarkScriptScreen(
            script: {
              'id': docRef.id,
              'name': finalName,
              'studentNumber': studentNumber,
              'ocrText': _extractedText,
              'timestamp': Timestamp.now(),
            },
            guideAnswers: [], 
          ),
        ),
      );
    } else {
      _clearForm();
    }
  } catch (e) {
    _showSnackBar("Failed to save: $e", isError: true);
  }
}


  void _clearForm() {
    setState(() {
      _nameController.clear();
      _studentNumberController.clear();
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
              const SizedBox(height: 16),

              TextField(
                controller: _studentNumberController,
                decoration: const InputDecoration(
                  labelText: 'Student Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              if (_imageFiles.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imageFiles.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_imageFiles[index], height: 100),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Remove Image?"),
                                      content: const Text("Are you sure you want to remove this image?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Remove")),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    setState(() {
                                      _imageFiles.removeAt(index);
                                      _extractedText = ''; // Optional: Clear extracted text on removal
                                    });
                                  }
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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

              const Text('Extracted & Structured Text:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt),
                          label: const Text("Save"),
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
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 1),
    );
  }
}
