import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';

class AnswerEntry {
  String question;
  String answer;

  AnswerEntry({required this.question, this.answer = ''});

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory AnswerEntry.fromJson(Map<String, dynamic> json) => AnswerEntry(
    question: json['question'] ?? '',
    answer: json['answer'] ?? '',
  );
}

class AnswerKeyScreen extends StatefulWidget {
  const AnswerKeyScreen({super.key});

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  final List<AnswerEntry> _entries = [];
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();

  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadFromFirebase();
  }

  void _addEntry() {
    if (_questionController.text.trim().isEmpty) return;
    if (_answerController.text.trim().isEmpty) return;

    setState(() {
      _entries.add(
        AnswerEntry(
          question: _questionController.text.trim(),
          answer: _answerController.text.trim(),
        ),
      );
      _questionController.clear();
      _answerController.clear();
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
    final doc =
        await FirebaseFirestore.instance
            .collection('answer_key')
            .doc('latest')
            .get();
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

      await FirebaseFirestore.instance
          .collection('answer_key')
          .doc('latest')
          .set({'answers': jsonList, 'timestamp': Timestamp.now()});

      await _clearDraft();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? "Answer key updated!"
                : "Answer key saved to Firebase!",
          ),
        ),
      );

      setState(() {
        _entries.clear();
        _isSaving = false;
        _isEditing = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Answer Key" : "Answer Key"),
        centerTitle: true,
      ),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                'This screen is for entering objective type questions only.',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Correct Answer',
                border: OutlineInputBorder(),
              ),
            ),
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
                const Text(
                  "Preview:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("Total: ${_entries.length} question(s)"),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  _entries.isEmpty
                      ? const Center(child: Text("No questions added."))
                      : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text("Q${index + 1}"),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Question: ${entry.question}"),
                                  Text("Answer: ${entry.answer}"),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
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
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child:
                  _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                        _isEditing
                            ? "Update Answer Key"
                            : "Save All to Firebase",
                      ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 3),
    );
  }
}
