import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ocr_service.dart';
import '../services/pdf_service.dart';
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
<<<<<<< HEAD
  final TextEditingController _directTextController = TextEditingController();
  bool _isSaving = false;
  bool _showDirectTextInput = false;
=======
>>>>>>> 4dfcae053d1a12ef3db0f2cf997b04a051121841

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

  @override
  void dispose() {
    _directTextController.dispose();
    super.dispose();
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
        .collection('marking_guides')  // Changed from 'answer_keys' to 'marking_guides'
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
          'source': data['source'] ?? 'manual', // Added source tracking
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

<<<<<<< HEAD
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
=======
  Future<void> _parseScannedAnswerKey(String rawText) async {
    final aiService = AIService();
>>>>>>> 4dfcae053d1a12ef3db0f2cf997b04a051121841

    try {
      final extractedEntries = await aiService.extractMarkingGuideFromText(rawText);
      _entries.clear();
      _entries.addAll(
        extractedEntries.map((e) => AnswerEntry.fromJson(e as Map<String, dynamic>))
      );

      _initControllersFromEntries();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Marking guide extracted successfully.")),
      );

      setState(() {
        _isEditing = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI extraction failed. Switching to manual mode.")),
      );

      _entries.clear();
      _addNewQuestion();
      setState(() {
        _isEditing = true;
      });
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

      await FirebaseFirestore.instance.collection('marking_guides').add({
        'title': guideName,
        'answers': jsonList,
        'timestamp': Timestamp.now(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'source': 'manual', // Track how this guide was created
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
      _isEditing = true;
    });
  }

  Future<void> _deleteGuide(String id) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('marking_guides').doc(id);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Guide not found.")),
        );
        return;
      }

      final data = docSnapshot.data()!;
      data['deletedAt'] = Timestamp.now();
      data['type'] = 'markingGuide';

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

  Future<void> _selectGuideForMarking(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_guide_id', id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Guide selected for marking.")),
    );

    setState(() {
      _selectedGuideId = id;
    });
<<<<<<< HEAD
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
=======
>>>>>>> 4dfcae053d1a12ef3db0f2cf997b04a051121841
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
      appBar: AppBar(
        title: const Text("Marking Guides"),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isEditing = false),
              tooltip: 'Cancel Editing',
            ),
        ],
      ),
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
                  prefixIcon: Icon(Icons.title),
                ),
              ),
<<<<<<< HEAD
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
=======
              const SizedBox(height: 20),
>>>>>>> 4dfcae053d1a12ef3db0f2cf997b04a051121841
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                itemBuilder: (context, index) => _buildAnswerCard(index),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Question"),
                      onPressed: _addNewQuestion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveToFirebase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text("Save Guide"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (!_isEditing) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "Create New Marking Guide",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.photo),
                              label: const Text("Scan from Image"),
                              onPressed: () => _scanFromSource(ImageSource.gallery),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.create),
                              label: const Text("Create Manually"),
                              onPressed: () {
                                _entries.clear();
                                _addNewQuestion();
                                setState(() => _isEditing = true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text(
                "Your Marking Guides",
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
                    final source = guide['source'] as String;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(guide['title']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Saved on ${savedDate.toString().substring(0, 10)}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              "Source: ${source == 'manual' ? 'Manually created' : 'Uploaded from script'}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
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
                                const PopupMenuItem(
                                  value: 'select',
                                  child: Text('Select for Marking'),
                                ),
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