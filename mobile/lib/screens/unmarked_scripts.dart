import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/dashboard_provider.dart';
import 'mark_script_screen.dart';
import 'answer_key_screen.dart';

class UnmarkedScriptsScreen extends StatefulWidget {
  const UnmarkedScriptsScreen({super.key});

  @override
  State<UnmarkedScriptsScreen> createState() => _UnmarkedScriptsScreenState();
}

class _UnmarkedScriptsScreenState extends State<UnmarkedScriptsScreen> {
  final int _limit = 10;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  List<Map<String, dynamic>> _scripts = [];
  List<dynamic> _selectedGuideAnswers = [];
  String? _selectedGuideTitle;

  @override
  void initState() {
    super.initState();
    _loadSelectedGuide();
    _fetchScripts(initialLoad: true);
  }

  Future<void> _loadSelectedGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedGuideId = prefs.getString('selected_guide_id');

    if (selectedGuideId == null) {
      setState(() {
        _selectedGuideAnswers = [];
        _selectedGuideTitle = null;
      });
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('answer_keys')
        .doc(selectedGuideId)
        .get();

    final data = doc.data();
    if (data != null && data['answers'] != null) {
      setState(() {
        _selectedGuideAnswers = List<Map<String, dynamic>>.from(data['answers']);
        _selectedGuideTitle = data['title'];
      });

      Provider.of<DashboardProvider>(context, listen: false).fetchStats();
    } else {
      setState(() {
        _selectedGuideAnswers = [];
        _selectedGuideTitle = null;
      });
    }
  }

  Future<void> _fetchScripts({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() {
        _scripts = [];
        _lastDocument = null;
        _hasMore = true;
      });
    }

    if (!_hasMore) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    Query query = FirebaseFirestore.instance
        .collection('scripts')
        .where('status', isEqualTo: 'unmarked')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(_limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    setState(() => _isLoadingMore = true);

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _scripts.addAll(snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return null;

              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unnamed Student',
                'ocrText': data['ocrText'] ?? '',
                'timestamp': data['timestamp'],
              };
            })
            .where((e) => e != null)
            .cast<Map<String, dynamic>>()
            .toList());

        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _limit;
      });
    } else {
      setState(() {
        _hasMore = false;
      });
    }

    setState(() => _isLoadingMore = false);
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM d, yyyy – hh:mm a').format(timestamp.toDate());
  }

  void _changeGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnswerKeyScreen()),
    ).then((_) => _loadSelectedGuide());
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _deleteAllScripts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All Scripts"),
        content: const Text("Are you sure you want to delete all unmarked scripts?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar("User not logged in.", isError: true);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('scripts')
          .where('status', isEqualTo: 'unmarked')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      // Move each script to history before deleting
      for (var doc in snapshot.docs) {
        final data = doc.data();

        final historyData = {
          ...data,
          'deletedAt': Timestamp.now(),
          'originalId': doc.id,
          'status': 'deleted',
        };

        final historyRef = FirebaseFirestore.instance.collection('history').doc(doc.id);
        batch.set(historyRef, historyData);
        batch.delete(doc.reference);
      }

      await batch.commit();

      _showSnackBar("✅ All unmarked scripts moved to history.");
      _fetchScripts(initialLoad: true);
      await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
    } catch (e) {
      _showSnackBar("Failed to delete scripts: $e", isError: true);
    }
  }

  Future<void> _confirmDeleteScript(String scriptId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Script"),
        content: const Text("Are you sure you want to delete this script? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final scriptDoc = await FirebaseFirestore.instance.collection('scripts').doc(scriptId).get();

      if (!scriptDoc.exists) {
        _showSnackBar("Script not found.", isError: true);
        return;
      }

      final data = scriptDoc.data()!;

      final historyData = {
        ...data,
        'deletedAt': Timestamp.now(),
        'originalId': scriptId,
        'status': 'deleted',
      };

      // Save to history collection
      await FirebaseFirestore.instance.collection('history').doc(scriptId).set(historyData);

      // Delete original document
      await FirebaseFirestore.instance.collection('scripts').doc(scriptId).delete();

      setState(() {
        _scripts.removeWhere((script) => script['id'] == scriptId);
      });

      _showSnackBar("Script moved to history.");
      await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
    } catch (e) {
      _showSnackBar("Failed to delete script: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unmarked Scripts"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "Delete All Scripts",
            onPressed: _deleteAllScripts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchScripts(initialLoad: true),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _scripts.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedGuideTitle != null)
                    Container(
                      color: Colors.green.shade50,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Using: $_selectedGuideTitle",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            onPressed: _changeGuide,
                            child: const Text("Change Guide"),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      color: Colors.amber.shade100,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Expanded(child: Text("No marking guide selected.")),
                          TextButton(
                            onPressed: _changeGuide,
                            child: const Text("Select Guide"),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }

            if (index == _scripts.length + 1) {
              if (_hasMore) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _isLoadingMore
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _fetchScripts,
                            child: const Text("Load More"),
                          ),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            }

            final script = _scripts[index - 1];
            final preview = script['ocrText'] ?? '';
            final timestamp = script['timestamp'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.description_outlined, color: Colors.grey),
                          title: Text(script['name'] ?? 'Student'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                preview.length > 100 ? '${preview.substring(0, 100)}...' : preview,
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
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text("Mark"),
                          onPressed: _selectedGuideAnswers.isEmpty
                              ? () => _showSnackBar("⚠ Please select a guide first", isError: true)
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MarkScriptScreen(
                                        script: script,
                                        guideAnswers: List<Map<String, dynamic>>.from(_selectedGuideAnswers),
                                      ),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _confirmDeleteScript(script['id']),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
