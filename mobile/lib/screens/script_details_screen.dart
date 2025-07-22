// NEW: ScriptDetailsScreen for showing script details and AI feedback
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScriptDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> script;
  const ScriptDetailsScreen({super.key, required this.script});

  @override
  Widget build(BuildContext context) {
    final name = script['name'] ?? 'Unnamed';
    final number = script['number'] ?? '';
    final score = script['score'] ?? 0;
    final total = script['total'] ?? '?';
    final method = script['method'] ?? 'manual';
    final aiFeedback = script['aiFeedback'] as String?;
    final timestamp = script['timestamp'];
    String markedStr = '';
    if (timestamp != null) {
      if (timestamp is DateTime) {
        markedStr = timestamp.toLocal().toString();
      } else if (timestamp is Timestamp) {
        markedStr = timestamp.toDate().toLocal().toString();
      } else {
        markedStr = timestamp.toString();
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Script Details'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'Name: $name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (number.isNotEmpty)
              Text(
                'Student Number: $number',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 10),
            Text(
              'Score: $score / $total',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Method: ${method.toString().toUpperCase()}',
              style: const TextStyle(fontSize: 16),
            ),
            if (timestamp != null)
              Text(
                'Marked: $markedStr',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const Divider(height: 30),
            if (aiFeedback != null && aiFeedback.trim().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Feedback:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(aiFeedback),
                  ),
                ],
              )
            else
              const Text(
                'No AI feedback available.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
