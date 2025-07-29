// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';

class AnswerEntry {
  String question;
  String modelAnswer;
  int marks;

  AnswerEntry({
    required this.question,
    required this.modelAnswer,
    required this.marks,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'modelAnswer': modelAnswer,
        'marks': marks,
      };

  factory AnswerEntry.fromJson(Map<String, dynamic> json) => AnswerEntry(
        question: json['question'] ?? '',
        modelAnswer: json['modelAnswer'] ?? '',
        marks: json['marks'] ?? 0,
      );
}

class AnswerKeyScreen extends StatefulWidget {
  const AnswerKeyScreen({super.key});

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  final List<AnswerEntry> _entries = [];
  final List<TextEditingController> _questionControllers = [];
  final List<TextEditingController> _answerControllers = [];
  final List<TextEditingController> _marksControllers = [];

  final TextEditingController _guideNameController = TextEditingController();
  final TextEditingController _directTextController = TextEditingController();
  bool _isSaving = false;
  bool _showDirectTextInput = false;

  // Track the currently selected guide ID
  String? _selectedGuideId;

  @override
  void initState() {
    super.initState();
    _loadSelectedGuideId();
  }

  @override
  void dispose() {
    _directTextController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedGuideId() async {
    final prefs = await SharedPreferences.getInstance();
    final guideId = prefs.getString('selected_guide_id');
    setState(() {
      _selectedGuideId = guideId;
    });
  }

  void _clearControllers() {
    _questionControllers.clear();
    _answerControllers.clear();
    _marksControllers.clear();
  }

  void _initControllersFromEntries() {
    _clearControllers();
    for (var entry in _entries) {
      _questionControllers.add(TextEditingController(text: entry.question));
      _answerControllers.add(TextEditingController(text: entry.modelAnswer));
      _marksControllers.add(TextEditingController(text: entry.marks.toString()));
    }
  }

  Future<void> _scanFromSource(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    try {
      final file = File(pickedFile.path);
      final text = await OCRService().extractTextFromImage(file);
      _parseScannedAnswerKey(text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Marking guide scanned. Edit before saving.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OCR error: $e")),
      );
    }
  }

  Future<void> _pickAndProcessPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String text = await PDFService().extractTextFromPdf(file);

        _parseScannedAnswerKey(text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ PDF processed. Edit before saving.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF processing error: $e")),
      );
    }
  }

  void _toggleDirectTextInput() {
    setState(() {
      _showDirectTextInput = !_showDirectTextInput;
      if (!_showDirectTextInput) {
        _directTextController.clear();
      }
    });
  }

  void _processDirectTextInput() {
    if (_directTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter some text to process")),
      );
      return;
    }

    _parseScannedAnswerKey(_directTextController.text);
    setState(() {
      _showDirectTextInput = false;
      _directTextController.clear();
    });
  }

  void _parseScannedAnswerKey(String rawText) {
    final lines = rawText.split('\n');
    String? currentQuestion;
    String currentAnswer = '';
    int currentMarks = 0;

    _entries.clear();

    for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final questionMatch = RegExp(r'^(?:Question|Q)?\s*(\d+)[.:)]?', caseSensitive: false)
          .firstMatch(trimmed);

      final marksMatch = RegExp(r'(\d+)\s+marks?', caseSensitive: false).firstMatch(trimmed);

      if (questionMatch != null) {
        if (currentQuestion != null && currentAnswer.trim().isNotEmpty) {
          _entries.add(AnswerEntry(
            question: currentQuestion,
            modelAnswer: currentAnswer.trim(),
            marks: currentMarks > 0 ? currentMarks : 1,
          ));
        }

        final qNum = questionMatch.group(1);
        currentQuestion = "Question $qNum";

        currentMarks = marksMatch != null ? int.parse(marksMatch.group(1)!) : 0;
        currentAnswer = '';
      } else {
        currentAnswer += '$line\n';
      }
    }

    if (currentQuestion != null && currentAnswer.trim().isNotEmpty) {
      _entries.add(AnswerEntry(
        question: currentQuestion,
        modelAnswer: currentAnswer.trim(),
        marks: currentMarks > 0 ? currentMarks : 1,
      ));
    }

    _initControllersFromEntries();
    setState(() {});
  }

  Future<void> _saveToFirebase() async {
    final guideName = _guideNameController.text.trim();

    if (guideName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ Please enter a guide title before saving.")),
      );
      return;
    }

    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❗ No entries found. Please scan or add questions.")),
      );
      return;
    }

    for (int i = 0; i < _entries.length; i++) {
      _entries[i] = AnswerEntry(
        question: _questionControllers[i].text.trim(),
        modelAnswer: _answerControllers[i].text.trim(),
        marks: int.tryParse(_marksControllers[i].text.trim()) ?? 1,
      );
    }

    setState(() => _isSaving = true);

    try {
      final jsonList = _entries.map((e) => e.toJson()).toList();

      await FirebaseFirestore.instance.collection('answer_keys').doc(guideName).set({
        'title': guideName,
        'answers': jsonList,
        'timestamp': Timestamp.now(),
      });

      await Provider.of<DashboardProvider>(context, listen: false).fetchStats();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Marking guide saved.")),
      );

      setState(() {
        _entries.clear();
        _guideNameController.clear();
        _clearControllers();
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Save failed: $e")),
      );
    }
  }

  Future<void> _setGuideForMarking(String guideId, String guideTitle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_guide_id', guideId);

    await Provider.of<DashboardProvider>(context, listen: false).fetchStats();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ '$guideTitle' set as current marking guide.")),
    );

    setState(() {
      _selectedGuideId = guideId;
    });
  }

  Future<void> _loadGuideForEditing(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> jsonList = data['answers'];

    setState(() {
      _guideNameController.text = data['title'];
      _entries.clear();
      _entries.addAll(jsonList.map((e) => AnswerEntry.fromJson(e)));
      _initControllersFromEntries();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ '${data['title']}' loaded for editing.")),
    );
  }

  void _confirmDeleteGuide(String guideId, String guideTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Marking Guide"),
        content: Text("Are you sure you want to delete '$guideTitle'? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                await FirebaseFirestore.instance
                    .collection('answer_keys')
                    .doc(guideId)
                    .delete();

                await Provider.of<DashboardProvider>(context, listen: false).fetchStats();

                // If the deleted guide was selected, clear selection
                if (_selectedGuideId == guideId) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('selected_guide_id');
                  setState(() {
                    _selectedGuideId = null;
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Guide deleted.")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ Failed to delete guide: $e")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _questionControllers[index],
              decoration: const InputDecoration(
                labelText: "Question",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerControllers[index],
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Enter model answer here",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _marksControllers[index],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Marks",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Marking Guide Scanner")),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            TextField(
              controller: _guideNameController,
              decoration: const InputDecoration(
                labelText: 'Guide Title',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // New PDF and Direct Text buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("PDF"),
                  onPressed: _pickAndProcessPdf,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.text_fields),
                  label: const Text("Direct Text"),
                  onPressed: _toggleDirectTextInput,
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Camera and Gallery buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                  onPressed: () => _scanFromSource(ImageSource.gallery),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                  onPressed: () => _scanFromSource(ImageSource.camera),
                ),
              ],
            ),
            
            // Direct Text Input Field
            if (_showDirectTextInput) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _directTextController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Paste answer key text',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _processDirectTextInput,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _toggleDirectTextInput,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _processDirectTextInput,
                    child: const Text('Process Text'),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            if (_entries.isNotEmpty) ...[
              const Text("Edit Scanned Questions", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                itemBuilder: (context, index) => _buildAnswerCard(index),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveToFirebase,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Guide"),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const Text("Saved Marking Guides", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('answer_keys')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No Key Found"));
                }

                final guides = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: guides.length,
                  itemBuilder: (context, index) {
                    final doc = guides[index];
                    final title = doc['title'];
                    final timestamp = (doc['timestamp'] as Timestamp).toDate();

                    final isSelected = _selectedGuideId == doc.id;

                    return Card(
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text("Saved on ${timestamp.toLocal().toString().split(' ')[0]}"),
                        trailing: Wrap(
                          spacing: 10,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _loadGuideForEditing(doc),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.check_circle,
                                color: isSelected ? Colors.green : Colors.grey,
                              ),
                              tooltip: 'Use for Marking',
                              onPressed: () => _setGuideForMarking(doc.id, title),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Guide',
                              onPressed: () => _confirmDeleteGuide(doc.id, title),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 3),
    );
  }
}