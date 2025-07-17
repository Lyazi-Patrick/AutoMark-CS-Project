import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnswerKeyScreen extends StatefulWidget {
  const AnswerKeyScreen({super.key});

  @override
  State<AnswerKeyScreen> createState() => _AnswerKeyScreenState();
}

class _AnswerKeyScreenState extends State<AnswerKeyScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _uploadAnswerKey() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance.collection('answer_keys').add({
        'key': _controller.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer key uploaded!')),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to upload: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _fetchLatestAnswerKey() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('answer_keys')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first['key'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Answer Key')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FutureBuilder<String?>(
              future: _fetchLatestAnswerKey(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final key = snapshot.data;
                return key != null
                    ? Card(
                        child: ListTile(
                          title: const Text('Latest Answer Key'),
                          subtitle: Text(key),
                        ),
                      )
                    : const Text('No answer key uploaded yet.');
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter new answer key',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadAnswerKey,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Upload Answer Key'),
            ),
          ],
        ),
      ),
    );
  }
}