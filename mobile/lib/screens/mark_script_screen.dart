import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/grading_logic.dart';
import '../services/ai_marking_service.dart';

class MarkScriptScreen extends StatefulWidget {
  const MarkScriptScreen({super.key});

  @override
  State<MarkScriptScreen> createState() => _MarkScriptScreenState();
}

class _MarkScriptScreenState extends State<MarkScriptScreen> {
  bool _isLoading = false;
  int? _score;
  int? _total;
  String? _aiMarkingResult;
  final _manualController = TextEditingController();

  // Helper to parse OCR text into Q/A pairs (naive example, adjust as needed)
  List<Map<String, String>> _parseQAPairs(String ocrText) {
    // Example: expects lines like Q: ...\nA: ...\n
    final lines = ocrText.split(RegExp(r'[\n\r]+'));
    List<Map<String, String>> pairs = [];
    String? currentQ;
    for (final line in lines) {
      if (line.trim().toUpperCase().startsWith('Q:')) {
        currentQ = line.substring(2).trim();
      } else if (line.trim().toUpperCase().startsWith('A:') &&
          currentQ != null) {
        pairs.add({'question': currentQ, 'answer': line.substring(2).trim()});
        currentQ = null;
      }
    }
    return pairs;
  }

  Future<void> _autoMark(Map<String, dynamic> script) async {
    setState(() => _isLoading = true);

    try {
      final answerKeySnap =
          await FirebaseFirestore.instance
              .collection('answer_key')
              .doc('latest')
              .get();

      if (!answerKeySnap.exists) {
        _showSnackBar("⚠ No answer key found", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final answerKey = answerKeySnap['answers'] as List<dynamic>;
      final parsedAnswers = parseAnswers(script['ocrText']);
      final score = gradeAnswers(parsedAnswers, answerKey);

      setState(() {
        _score = score;
        _total = answerKey.length;
      });

      await _saveResult(script, score, answerKey.length, method: 'auto');
    } catch (e) {
      _showSnackBar("Auto-marking failed: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // NEW: Calls the AI marking service with parsed Q/A pairs and updates the UI with the result
  Future<void> _aiMark(Map<String, dynamic> script) async {
    setState(() => _isLoading = true);
    try {
      final ocrText = script['ocrText'] ?? '';
      final qaPairs = _parseQAPairs(ocrText);
      if (qaPairs.isEmpty) {
        _showSnackBar("No Q/A pairs found in OCR text.", isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final aiResult = await AIMarkingService.markAnswersWithAI(
        qaPairs,
      ); // NEW: Send to Cohere
      setState(() {
        _aiMarkingResult = aiResult; // NEW: Store AI feedback
      });
      await _saveResult(
        script,
        null,
        null,
        method: 'ai',
        aiFeedback: aiResult,
      ); // NEW: Save AI result
    } catch (e) {
      _showSnackBar("AI marking failed: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveManualScore(Map<String, dynamic> script) async {
    final score = int.tryParse(_manualController.text.trim());
    if (score == null || score < 0) {
      _showSnackBar("⚠ Enter a valid positive number", isError: true);
      return;
    }

    // Optional: You can set a maximum score limit if desired
    if (score > 100) {
      _showSnackBar("⚠ Score too high! Max is 100", isError: true);
      return;
    }

    await _saveResult(script, score, null, method: 'manual');
  }

  // NEW: Save result now supports saving AI feedback (aiFeedback param)
  Future<void> _saveResult(
    Map<String, dynamic> script,
    int? score,
    int? total, {
    required String method,
    String? aiFeedback,
  }) async {
    final id = script['id'];

    // Save to /results
    await FirebaseFirestore.instance.collection('results').add({
      'name': script['name'],
      'score': score ?? 0,
      'total': total ?? 0,
      'method': method,
      'aiFeedback': aiFeedback, // NEW: Save AI feedback
      'timestamp': Timestamp.now(),
    });

    // Update script status to 'marked'
    await FirebaseFirestore.instance.collection('scripts').doc(id).update({
      'status': 'marked',
      'score': score ?? 0,
      'total': total ?? 0,
      'method': method,
      'aiFeedback': aiFeedback, // NEW: Save AI feedback
    });

    _showSnackBar("✅ Script marked successfully!");
    Navigator.pop(context);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final script =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final submissionTime =
        script['timestamp'] != null
            ? (script['timestamp'] as Timestamp).toDate()
            : null;

    return Scaffold(
      appBar: AppBar(title: Text("Mark Script - ${script['name']}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metadata
                    if (submissionTime != null)
                      Text(
                        "Submitted: ${submissionTime.toLocal()}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 12),

                    const Text(
                      "Extracted Script Text:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // OCR Text
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade100,
                        ),
                        child: SingleChildScrollView(
                          child: Text(script['ocrText'] ?? 'No text'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(),

                    // Auto mark
                    ElevatedButton.icon(
                      icon: const Icon(Icons.bolt),
                      label: const Text("Auto Mark"),
                      onPressed: () => _autoMark(script),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blue,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // NEW: Button to trigger AI marking using Cohere
                    ElevatedButton.icon(
                      icon: const Icon(Icons.smart_toy),
                      label: const Text("AI Mark (Cohere)"),
                      onPressed: () => _aiMark(script),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Manual mark
                    TextField(
                      controller: _manualController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Enter Manual Score",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Submit Manual Score"),
                      onPressed: () => _saveManualScore(script),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),

                    // Result preview
                    if (_score != null && _total != null) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          "Preview Score: $_score / $_total",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                    // NEW: Display the AI marking feedback/result if available
                    if (_aiMarkingResult != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        "AI Marking Feedback:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_aiMarkingResult!),
                      ),
                    ],
                  ],
                ),
      ),
    );
  }
}
