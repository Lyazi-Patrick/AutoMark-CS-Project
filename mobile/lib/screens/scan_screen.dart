import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/answer_provider.dart';
import '../providers/result_provider.dart';
import '../utils/grading_logic.dart';
import '../widgets/custom_drawer.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String scannedText = '';
  File? _pickedImage;
  bool _fromBatchScan = false;
  bool _hasOpenedCamera = false; // Prevent reopening camera repeatedly

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && scannedText.isEmpty) {
      setState(() {
        scannedText = args;
        _fromBatchScan = true;
      });

      final parsedStudentAnswers = parseAnswers(args);
      final answerEntries = context.read<AnswerProvider>().entries;

      final score = gradeAnswers(parsedStudentAnswers, answerEntries);
      context.read<ResultProvider>().setResult(score, answerEntries.length);

      Navigator.pushNamed(context, '/result');
    }
  }

  @override
  void initState() {
    super.initState();

    // Auto open camera only once on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasOpenedCamera && !_fromBatchScan) {
        _hasOpenedCamera = true;
        _pickImage(ImageSource.camera);
      }
    });
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
    await textRecognizer.close();

    final extractedText = recognizedText.text;
    setState(() => scannedText = extractedText);

    final parsedStudentAnswers = parseAnswers(extractedText);
    final answerEntries = context.read<AnswerProvider>().entries;

    final score = gradeAnswers(parsedStudentAnswers, answerEntries);
    context.read<ResultProvider>().setResult(score, answerEntries.length);

    Navigator.pushNamed(context, '/result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Script")),
      drawer: const CustomDrawer(),
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

extension on ResultProvider {
  void calculateScore(List<String> studentAnswers, correctAnswers) {}
}

// Dummy ResultProvider for demonstration; replace with your actual implementation
class ResultProvider extends ChangeNotifier {
  int _score = 0;
  int _total = 0;

  void setResult(int score, int total) {
    _score = score;
    _total = total;
    notifyListeners();
  }

  int get score => _score;
  int get total => _total;
}

class AnswerProvider extends ChangeNotifier {
    List<String> entries = [];
    void setEntries(List<String> newEntries) {
      entries = newEntries;
      notifyListeners();
    }
  }