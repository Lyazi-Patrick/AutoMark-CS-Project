import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ocr_service.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';
import '../models/answer_entry.dart';
import '../services/ai_service.dart';

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

  bool _isSaving = false;
  bool _isEditing = false;

  String? _selectedGuideId;
  List<Map<String, dynamic>> _savedGuides = [];

  // Pagination variables
  List<QueryDocumentSnapshot> _guideDocs = [];
  DocumentSnapshot? _lastGuideDoc;
  bool _isLoadingMore = false;
  bool _hasMoreGuides = true;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadSelectedGuideId();
    _fetchSavedGuides(isInitial: true);
  }

  Future<void> _loadSelectedGuideId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedGuideId = prefs.getString('selected_guide_id');
    });
  }

  Future<void> _fetchSavedGuides({bool isInitial = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_isLoadingMore || !_hasMoreGuides) return;

    setState(() => _isLoadingMore = true);

    Query query = FirebaseFirestore.instance
        .collection('answer_keys')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (!isInitial && _lastGuideDoc != null) {
      query = query.startAfterDocument(_lastGuideDoc!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastGuideDoc = snapshot.docs.last;
      _guideDocs.addAll(snapshot.docs);
    }

    if (snapshot.docs.length < _pageSize) {
      _hasMoreGuides = false;
    }

    setState(() {
      _savedGuides = _guideDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Guide',
          'answers': data['answers'] ?? [],
          'timestamp': data['timestamp'],
        };
      }).toList();
      _isLoadingMore = false;
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
      _marksControllers.add(TextEditingController(text: entry.marks?.toString() ?? '1'));
    }
  }

  void _addNewQuestion() {
    setState(() {
      _entries.add(AnswerEntry(question: '', modelAnswer: '', marks: 1));
      _questionControllers.add(TextEditingController());
      _answerControllers.add(TextEditingController());
      _marksControllers.add(TextEditingController(text: '1'));
    });
  }

  Future<void> _scanFromSource(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    try {
      final file = File(pickedFile.path);
      final text = await OCRService().extractTextFromImage(file);
      await _parseScannedAnswerKey(text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OCR error: $e")),
      );
    }
  }

  Future<void> _parseScannedAnswerKey(String rawText) async {
  final aiService = AIService();

  try {
    // Stage 1: Try AI extraction
    final extractedEntries = await aiService.extractMarkingGuideFromText(rawText);

    if (extractedEntries.isEmpty) throw Exception("AI returned empty list");

    _entries.clear();
    _entries.addAll(extractedEntries.map((e) => AnswerEntry.fromJson(e)));

    _initControllersFromEntries();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Marking guide extracted successfully.")),
    );

    _selectedGuideId = null;
    setState(() => _isEditing = true);
  } catch (e) {
    debugPrint("AI extraction failed: $e");
    // Stage 2: Try simple rule-based fallback
    final fallbackEntries = _basicParseFallback(rawText);

    if (fallbackEntries.isNotEmpty) {
      _entries.clear();
      _entries.addAll(fallbackEntries);
      _initControllersFromEntries();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Fallback parser used for marking guide.")),
      );
      _selectedGuideId = null;
      setState(() => _isEditing = true);
      return;
    }

    // Final fallback: manual entry
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❌ Could not extract. Please enter manually.")),
    );
    _selectedGuideId = null;
    _entries.clear();
    _addNewQuestion();
    setState(() => _isEditing = true);
  }
}


  Future<void> _saveToFirebase() async {
  final guideName = _guideNameController.text.trim();

  if (guideName.isEmpty || _entries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("❗ Please enter a guide title and at least one entry.")),
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

    final Map<String, dynamic> data = {
      'title': guideName,
      'answers': jsonList,
      'timestamp': Timestamp.now(),
      'userId': FirebaseAuth.instance.currentUser!.uid,
    };

    final collectionRef = FirebaseFirestore.instance.collection('answer_keys');

    if (_isEditing && _selectedGuideId != null) {
      final docRef = collectionRef.doc(_selectedGuideId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.update(data);
      } else {
        // Fallback: create it instead
        final newDoc = await collectionRef.add(data);
        _selectedGuideId = newDoc.id;
      }
    } else {
      // Create new document with only allowed fields
      final newDoc = await collectionRef.add(data);
      _selectedGuideId = newDoc.id;
    }


    await Provider.of<DashboardProvider>(context, listen: false).fetchStats();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Marking guide saved.")),
    );

    setState(() {
      _entries.clear();
      _guideNameController.clear();
      _clearControllers();
      _isSaving = false;
      _isEditing = false;
      _guideDocs.clear();
      _lastGuideDoc = null;
      _hasMoreGuides = true;
    });

    _fetchSavedGuides(isInitial: true);
  } catch (e) {
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ Save failed: $e")),
    );
  }
}

  void _editGuide(Map<String, dynamic> guide) {
    _entries.clear();

    final answers = guide['answers'] as List<dynamic>;
    for (var ans in answers) {
      _entries.add(AnswerEntry.fromJson(Map<String, dynamic>.from(ans)));
    }

    _guideNameController.text = guide['title'];
    _initControllersFromEntries();

    setState(() {
      _selectedGuideId = guide['id']; 
      _isEditing = true;
    });
  }

  Future<void> _deleteGuide(String id) async {
  try {
    final docRef = FirebaseFirestore.instance.collection('answer_keys').doc(id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Guide not found.")),
      );
      return;
    }

   final data = docSnapshot.data()!;
  data['deletedAt'] = Timestamp.now();
  data['type'] = 'markingGuide'; // Important for History screen filtering
  data['userId'] = FirebaseAuth.instance.currentUser!.uid; // ✅ Required by Firestore rules

  // Store in history
  await FirebaseFirestore.instance.collection('history').add(data);

    // Delete from original collection
    await docRef.delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🗑️ Guide moved to history.")),
    );

    await Provider.of<DashboardProvider>(context, listen: false).fetchStats();

    setState(() {
      _guideDocs.clear();
      _lastGuideDoc = null;
      _hasMoreGuides = true;
    });

    _fetchSavedGuides(isInitial: true);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Delete failed: $e")),
    );
  }
}

List<AnswerEntry> _basicParseFallback(String text) {
  final lines = text.split('\n');
  final entries = <AnswerEntry>[];

  String? question;
  String? modelAnswer;
  int marks = 1;

  for (var line in lines) {
    line = line.trim();

    if (line.startsWith(RegExp(r'(Q\d+[:.])'))) {
      if (question != null && modelAnswer != null) {
        entries.add(AnswerEntry(question: question!, modelAnswer: modelAnswer!, marks: marks));
      }
      question = line.replaceFirst(RegExp(r'(Q\d+[:.])'), '').trim();
      modelAnswer = null;
      marks = 1;
    } else if (line.toLowerCase().startsWith('answer:')) {
      modelAnswer = line.replaceFirst('Answer:', '').trim();
    } else if (line.toLowerCase().startsWith('marks:')) {
      marks = int.tryParse(line.replaceFirst('Marks:', '').trim()) ?? 1;
    }
  }

  // Catch the last entry
  if (question != null && modelAnswer != null) {
    entries.add(AnswerEntry(question: question, modelAnswer: modelAnswer, marks: marks));
  }

  return entries;
}



  Future<void> _selectGuideForMarking(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_guide_id', id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Guide selected for marking.")),
    );

    setState(() {
      _selectedGuideId = id;
    });
  }

  Widget _buildAnswerCard(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _questionControllers[index],
              decoration: const InputDecoration(
                labelText: "Question",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _answerControllers[index],
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "Model Answer",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _marksControllers[index],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Marks (default: 1)",
                border: OutlineInputBorder(),
              ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditing) ...[
              TextField(
                controller: _guideNameController,
                decoration: const InputDecoration(
                  labelText: 'Guide Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                itemBuilder: (context, index) => _buildAnswerCard(index),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Question"),
                onPressed: _addNewQuestion,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveToFirebase,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text("Save Guide"),
              ),
            ],
            if (!_isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo),
                      label: const Text("Gallery"),
                      onPressed: () => _scanFromSource(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Camera"),
                      onPressed: () => _scanFromSource(ImageSource.camera),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text(
                "Saved Marking Guides",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_savedGuides.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _savedGuides.length + (_hasMoreGuides ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _savedGuides.length) {
                      _fetchSavedGuides();
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final guide = _savedGuides[index];
                    final isSelected = guide['id'] == _selectedGuideId;
                    final savedDate = (guide['timestamp'] as Timestamp).toDate();

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(guide['title']),
                        subtitle: Text(
                          "Saved on ${savedDate.toString().substring(0, 10)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 16),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _editGuide(guide);
                                if (value == 'delete') _deleteGuide(guide['id']);
                                if (value == 'select') _selectGuideForMarking(guide['id']);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                const PopupMenuItem(value: 'select', child: Text('Select for Marking')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 3),
    );
  }
}
