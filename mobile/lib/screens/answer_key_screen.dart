import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';

class AnswerEntry {
  String type;
  String answer;
  List<String> keywords;

  AnswerEntry({
    required this.type,
    this.answer = '',
    this.keywords = const [],
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'answer': answer,
        'keywords': keywords,
      };

  factory AnswerEntry.fromJson(Map<String, dynamic> json) => AnswerEntry(
        type: json['type'],
        answer: json['answer'] ?? '',
        keywords: List<String>.from(json['keywords'] ?? []),
      );
}

class AnswerKeyScreen extends StatefulWidget {
  const AnswerKeyScreen({super.key});

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  final List<AnswerEntry> _entries = [];
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();

  String _selectedType = 'Objective';
  List<String> _keywords = [];
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _loadFromFirebase();
  }

  void _addEntry() {
    if (_selectedType == 'Objective' && _answerController.text.trim().isEmpty) return;
    if (_selectedType == 'Keyword' && _keywords.isEmpty) return;

    setState(() {
      _entries.add(
        AnswerEntry(
          type: _selectedType,
          answer: _selectedType == 'Objective' ? _answerController.text.trim() : '',
          keywords: _selectedType == 'Keyword' ? List.from(_keywords) : [],
        ),
      );
      _answerController.clear();
      _keywordController.clear();
      _keywords.clear();
    });

    _saveDraft();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('answer_key_draft', encoded);
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('answer_key_draft');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      setState(() {
        _entries.clear();
        _entries.addAll(jsonList.map((e) => AnswerEntry.fromJson(e)));
      });
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('answer_key_draft');
  }

  Future<void> _loadFromFirebase() async {
    final doc = await FirebaseFirestore.instance.collection('answer_key').doc('latest').get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('answers')) {
        final List<dynamic> jsonList = data['answers'];
        setState(() {
          _entries.clear();
          _entries.addAll(jsonList.map((e) => AnswerEntry.fromJson(e)));
          _isEditing = true;
        });
      }
    }
  }

  Future<void> _saveToFirebase() async {
    if (_entries.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final jsonList = _entries.map((e) => e.toJson()).toList();

      await FirebaseFirestore.instance.collection('answer_key').doc('latest').set({
        'answers': jsonList,
        'timestamp': Timestamp.now(),
      });

      await _clearDraft();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? "Answer key updated!" : "Answer key saved to Firebase!")),
      );

      setState(() {
        _entries.clear();
        _isSaving = false;
        _isEditing = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Answer Key" : "Answer Key"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: "Restore Draft",
            onPressed: _loadDraft,
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: const [
                DropdownMenuItem(value: 'Objective', child: Text('Objective')),
                DropdownMenuItem(value: 'Keyword', child: Text('Sentence (Keywords)')),
              ],
              onChanged: (value) => setState(() => _selectedType = value!),
              decoration: const InputDecoration(
                labelText: 'Answer Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedType == 'Objective')
              TextField(
                controller: _answerController,
                decoration: const InputDecoration(
                  labelText: 'Correct Answer (e.g., A)',
                  border: OutlineInputBorder(),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordController,
                      decoration: const InputDecoration(
                        labelText: 'Keyword',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (_keywordController.text.trim().isNotEmpty) {
                        setState(() {
                          _keywords.add(_keywordController.text.trim());
                          _keywordController.clear();
                        });
                        _saveDraft();
                      }
                    },
                    child: const Text("Add"),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                children: _keywords.map((e) => Chip(label: Text(e))).toList(),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add),
              label: const Text("Add Question"),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Preview:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Total: ${_entries.length} question(s)"),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text("No questions added."))
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(child: Text("Q${index + 1}")),
                            title: entry.type == 'Objective'
                                ? Text("Objective: ${entry.answer}")
                                : Text("Keywords: ${entry.keywords.join(', ')}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() => _entries.removeAt(index));
                                _saveDraft();
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveToFirebase,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEditing ? "Update Answer Key" : "Save All to Firebase"),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 3),
    );
  }
}