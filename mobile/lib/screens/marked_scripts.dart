import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';

class MarkedScriptsScreen extends StatefulWidget {
  const MarkedScriptsScreen({super.key});

  @override
  State<MarkedScriptsScreen> createState() => _MarkedScriptsScreenState();
}

class _MarkedScriptsScreenState extends State<MarkedScriptsScreen> {
  final List<QueryDocumentSnapshot> _scripts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchScripts();
  }

  Future<void> _fetchScripts() async {
    if (_isLoading || !_hasMore) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance
        .collection('scripts')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'marked')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _scripts.addAll(snapshot.docs);
    }

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false; // No more data
    }

    setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    setState(() {
      _scripts.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchScripts();
    await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    return DateFormat('MMM d, yyyy – hh:mm a').format(timestamp.toDate());
  }

  Color getMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'ai':
        return Colors.deepPurple;
      case 'auto':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Future<void> _deleteScript(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Script"),
        content: const Text("Are you sure you want to delete this marked script?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
  final deletedDoc = FirebaseFirestore.instance.collection('scripts').doc(docId);
  final docSnapshot = await deletedDoc.get();

  if (docSnapshot.exists) {
    final data = docSnapshot.data()!;
    data['deletedAt'] = Timestamp.now(); // For auto-deletion tracking

    await FirebaseFirestore.instance
        .collection('history')
        .doc(docId)
        .set(data);

    await deletedDoc.delete(); // Only delete after moving
  }

  setState(() {
    _scripts.removeWhere((doc) => doc.id == docId);
  });

  await Provider.of<DashboardProvider>(context, listen: false).fetchStats();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Script moved to history.")),
  );
}

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Marked Scripts"),
        centerTitle: true,
      ),
      drawer: const CustomDrawer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: _scripts.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _scripts.length) {
              // Loader at the bottom
              _fetchScripts();
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final doc = _scripts[index];
            final data = doc.data() as Map<String, dynamic>;

            final name = data['name'] ?? 'Unnamed';
            final score = data['score'] ?? 0;
            final total = data['total'] ?? '?';
            final method = data['method'] ?? 'manual';
            final timestamp = data['timestamp'] as Timestamp?;
            final feedback = data['feedback'];

            return Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Score: $score / $total"),
                          Text(
                            "Method: ${method.toUpperCase()}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: getMethodColor(method),
                            ),
                          ),
                          Text(
                            "Marked: ${formatTimestamp(timestamp)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteScript(context, doc.id),
                        tooltip: "Delete",
                      ),
                    ),
                    if (feedback != null && feedback.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                        child: Text(
                          "AI Feedback: $feedback",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 3),
    );
  }
}
