import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting timestamps

class UnmarkedScriptsScreen extends StatelessWidget {
  const UnmarkedScriptsScreen({super.key});

  Future<List<Map<String, dynamic>>> fetchUnmarkedScripts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('scripts')
        .where('status', isEqualTo: 'unmarked')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM d, yyyy – hh:mm a').format(timestamp.toDate());
  }

  Future<void> deleteScript(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Script"),
        content: const Text("Are you sure you want to delete this script?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('scripts').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Script deleted.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unmarked Scripts"),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchUnmarkedScripts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final scripts = snapshot.data ?? [];

          if (scripts.isEmpty) {
            return const Center(child: Text("🎉 All scripts are marked."));
          }

          return ListView.builder(
            itemCount: scripts.length,
            itemBuilder: (context, index) {
              final script = scripts[index];
              final ocrPreview = script['ocrText'] ?? '';
              final timestamp = script['timestamp'] as Timestamp?;
              final docId = script['id'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: Colors.grey),
                  title: Text(script['name'] ?? 'Unnamed Student'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        ocrPreview.length > 100 ? '${ocrPreview.substring(0, 100)}...' : ocrPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Uploaded: ${formatTimestamp(timestamp)}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Column(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Mark"),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/mark_script',
                            arguments: script,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Delete script",
                        onPressed: () => deleteScript(context, docId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}