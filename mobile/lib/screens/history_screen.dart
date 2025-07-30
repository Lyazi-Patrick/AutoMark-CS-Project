import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final int _limit = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  final List<Map<String, dynamic>> _deletedScripts = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchDeletedScripts(initialLoad: true);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchDeletedScripts();
    }
  }

  Future<void> _fetchDeletedScripts({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() {
        _deletedScripts.clear();
        _lastDocument = null;
        _hasMore = true;
      });
    }

    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('history')
          .orderBy('deletedAt', descending: true)
          .limit(_limit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        final newScripts = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;

          if (data == null) return null;

          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed Student',
            'ocrText': data['ocrText'] ?? '',
            'deletedAt': data['deletedAt'],
          };
        }).whereType<Map<String, dynamic>>().toList();

        setState(() {
          _deletedScripts.addAll(newScripts);
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length == _limit;
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Error fetching deleted scripts: $e\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch scripts: $e")),
      );
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    // Use timeago package for friendly time difference
    return timeago.format(timestamp.toDate());
  }

  Future<void> _permanentlyDeleteScript(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permanently Delete Script"),
        content: const Text(
            "This will permanently delete the script from history. This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistically update UI before awaiting Firestore deletion
    setState(() {
      _deletedScripts.removeWhere((script) => script['id'] == docId);
    });

    try {
      await FirebaseFirestore.instance.collection('history').doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Script permanently deleted.")),
      );
    } catch (e, stackTrace) {
      debugPrint("Failed to permanently delete: $e\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete script: $e")),
      );
      // Optionally, reload scripts to reflect actual data if deletion failed
      _fetchDeletedScripts(initialLoad: true);
    }
  }

  Future<void> _restoreScript(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Restore Script"),
        content:
            const Text("This will restore the script back to unmarked scripts."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Restore"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistic UI update
    setState(() {
      _deletedScripts.removeWhere((script) => script['id'] == docId);
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('history').doc(docId).get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Script not found in history.")),
        );
        return;
      }

      final data = doc.data()!;
      final restoredData = Map<String, dynamic>.from(data);
      restoredData.remove('deletedAt'); // Remove deletedAt on restore
      restoredData.remove('status'); // Optional
      restoredData.remove('originalId'); // Optional

      // Write back to scripts collection with status 'unmarked'
      restoredData['status'] = 'unmarked';

      await FirebaseFirestore.instance.collection('scripts').doc(docId).set(restoredData);

      // Remove from history
      await FirebaseFirestore.instance.collection('history').doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Script restored successfully.")),
      );
    } catch (e, stackTrace) {
      debugPrint("Failed to restore script: $e\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to restore script: $e")),
      );
      // Reload on failure
      _fetchDeletedScripts(initialLoad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deleted Scripts History"),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchDeletedScripts(initialLoad: true),
        child: _deletedScripts.isEmpty && !_isLoadingMore
            ? const Center(child: Text("No deleted scripts found."))
            : ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _deletedScripts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _deletedScripts.length) {
                    // Show loading indicator at bottom when fetching more
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final script = _deletedScripts[index];
                  final preview = script['ocrText'] ?? '';
                  final deletedAt = script['deletedAt'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      title: Text(script['name'] ?? 'Unnamed Student'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            preview.length > 100 ? '${preview.substring(0, 100)}...' : preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Deleted: ${formatTimestamp(deletedAt)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'restore') {
                            _restoreScript(script['id']);
                          } else if (value == 'delete') {
                            _permanentlyDeleteScript(script['id']);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'restore',
                            child: Text('Restore'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Permanently'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
