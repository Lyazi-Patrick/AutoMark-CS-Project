import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/answer_provider.dart';
import '../providers/result_provider.dart';
import '../widgets/custom_drawer.dart'; // ✅ Corrected import

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String scannedText = '';
  File? _pickedImage;
  bool _fromBatchScan = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && scannedText.isEmpty) {
      setState(() {
        scannedText = args;
        _fromBatchScan = true;
      });

      final studentAnswers = args
          .replaceAll('\n', ',')
          .split(',')
          .map((e) => e.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toList();

      final correctAnswers = context.read<AnswerProvider>().correctAnswers;
      context.read<ResultProvider>().calculateScore(studentAnswers, correctAnswers);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    setState(() {
      _pickedImage = imageFile;
      scannedText = '';
    });

    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);

    final extractedText = recognizedText.text;
    setState(() {
      scannedText = extractedText;
    });

    final studentAnswers = extractedText
        .replaceAll('\n', ',')
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final correctAnswers = context.read<AnswerProvider>().correctAnswers;
    context.read<ResultProvider>().calculateScore(studentAnswers, correctAnswers);

    await textRecognizer.close();

    Navigator.pushNamed(context, '/result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Script")),
      drawer: const CustomDrawer(), // ✅ Add drawer here
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!_fromBatchScan)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            _pickedImage != null
                ? Image.file(_pickedImage!, height: 200)
                : !_fromBatchScan
                    ? const Text("No image selected.")
                    : const SizedBox(),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  scannedText.isEmpty ? "No text extracted." : scannedText,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}