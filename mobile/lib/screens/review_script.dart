import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewScriptScreen extends StatefulWidget {
  final String scriptId;

  const ReviewScriptScreen({super.key, required this.scriptId});

  @override
  State<ReviewScriptScreen> createState() => _ReviewScriptScreenState();
}

class _ReviewScriptScreenState extends State<ReviewScriptScreen> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _scriptFuture;

  @override
  void initState() {
    super.initState();
    _scriptFuture = fetchScript();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchScript() {
    return FirebaseFirestore.instance.collection('scripts').doc(widget.scriptId).get();
  }

  Future<void> _remarkQuestion(int index, int maxMarks, int currentMarks) async {
  final TextEditingController controller = TextEditingController(text: currentMarks.toString());

  final newMarks = await showDialog<int>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Remark Question ${index + 1}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Enter new marks (0-$maxMarks)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final entered = int.tryParse(controller.text);
              if (entered == null || entered < 0 || entered > maxMarks) {
                return;
              }
              Navigator.pop(context, entered);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (newMarks != null && newMarks != currentMarks) {
    final docRef = FirebaseFirestore.instance.collection('scripts').doc(widget.scriptId);
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data()!;
    List questions = data['questions'] ?? [];

    if (index < questions.length) {
      questions[index]['score'] = newMarks;
    }

    int totalMarks = 0;
    for (var q in questions) {
      final awarded = q['score'] as num? ?? 0;
      totalMarks += awarded.toInt();
    }

    // Update 'scripts' document
    await docRef.update({
      'questions': questions,
      'totalMarks': totalMarks,
    });

    // Also update 'results' document (assuming same doc ID)
    final resultDocRef = FirebaseFirestore.instance.collection('results').doc(widget.scriptId);

    // It’s good to check if the document exists before update
    final resultSnapshot = await resultDocRef.get();
    if (resultSnapshot.exists) {
      await resultDocRef.update({
        'score': totalMarks,
        'total': totalMarks, // or keep original total if needed
        'timestamp': FieldValue.serverTimestamp(), // update timestamp optionally
      });
    }

    // Refresh UI
    setState(() {
      _scriptFuture = fetchScript();
    });
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Marked Script'),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _scriptFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Script not found."));
          }

          final data = snapshot.data!.data()!;
          final studentName = data['name'] ?? 'Unknown Student';
          final studentNumber = data['studentNumber'] ?? 'Unknown Number';
          final questions = List<Map<String, dynamic>>.from(data['details'] ?? []);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Name: $studentName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Student Number: $studentNumber', style: const TextStyle(fontSize: 16)),
                    const Divider(height: 32),
                  ],
                ),
              ),

              // Question list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    final question = q['question'] ?? 'N/A';
                    final studentAnswer = q['studentAnswer'] ?? 'N/A';
                    final correctAnswer = q['modelAnswer'] ?? 'N/A';  // Changed key
                    final awardedMarks = q['score'] ?? 0;             // Changed key
                    final maxMarks = q['allocatedMarks'] ?? 1;              // Changed key

                    final isCorrect = studentAnswer.toString().trim().toLowerCase() ==
                        correctAnswer.toString().trim().toLowerCase();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isCorrect ? Colors.green[50] : Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Q${index + 1}: $question", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text("Student Answer: $studentAnswer"),
                            Text("Correct Answer: $correctAnswer"),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Marks: $awardedMarks / $maxMarks", style: const TextStyle(fontWeight: FontWeight.w500)),
                                if (!isCorrect)
                                  TextButton.icon(
                                    onPressed: () => _remarkQuestion(index, maxMarks, awardedMarks),
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text("Remark"),
                                  )
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
