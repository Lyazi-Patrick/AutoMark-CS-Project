import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_file/open_file.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _openPDF(String path, BuildContext context) async {
    final file = File(path);
    if (await file.exists()) {
      await OpenFile.open(path);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("File not found.")));
    }
  }

  Future<void> _deleteDownload(
    String docId,
    String filePath,
    BuildContext context,
  ) async {
    try {
      // Deletes Firestore record
      await FirebaseFirestore.instance
          .collection('downloads')
          .doc(docId)
          .delete();

      // Delete the local file if exists
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Download deleted.")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Downloaded Reports")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('downloads')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("No downloads yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'];
              final filePath = data['filePath'];

              return ListTile(
                title: Text(title),
                subtitle: Text(filePath),
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openPDF(filePath, context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _deleteDownload(doc.id, filePath, context),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
