import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/dashboard_provider.dart';
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

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Getter to filter scripts based on _searchQuery
  List<QueryDocumentSnapshot> get _filteredScripts {
    if (_searchQuery.isEmpty) return _scripts;
    return _scripts.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name']?.toString().toLowerCase() ?? '';
      final studentNumber = data['studentNumber']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery) || studentNumber.contains(_searchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchScripts();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
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
      _hasMore = false;
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

Future<void> _deleteResult(BuildContext context, String docId, Map<String, dynamic> data) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Delete Result"),
      content: const Text("Are you sure you want to delete this marked script?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final historyData = {
        'name': data['name'],
        'score': data['score'],
        'feedback': data['feedback'],
        'timestamp': data['timestamp'] is Timestamp ? data['timestamp'] : Timestamp.now(),
        'deletedAt': Timestamp.now(),
        'userId': userId,
        'status': 'deleted',
        'originalId': docId,
        'type': 'result',
        'total': data['total'] ?? 0,
        'method': data['method'] ?? '',
        'studentNumber': data['studentNumber'] ?? '',
      };

      // Step 1: Copy to history
      await FirebaseFirestore.instance.collection('history').add(historyData);

      // Step 2: Delete original
      await FirebaseFirestore.instance.collection('scripts').doc(docId).delete();

      setState(() {
        _scripts.removeWhere((doc) => doc.id == docId);
        _searchQuery = _searchQuery;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marked script moved to history.")),
      );
    } catch (e) {
      print('Error deleting result: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete marked script.")),
      );
    }
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Marked Scripts"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      drawer: const CustomDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or student number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: _filteredScripts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _filteredScripts.length) {
                    _fetchScripts();
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final doc = _filteredScripts[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final name = data['name'] ?? 'Unnamed';
                  final studentNumber = data['studentNumber'] ?? '';
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
                            title: Text(
                              "$name${studentNumber.isNotEmpty ? ' ($studentNumber)' : ''}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                              onPressed: () => _deleteResult(context, doc.id, data),
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
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/reviewScript',
                                  arguments: {
                                    'docId': doc.id,
                                    'data': data,
                                  },
                                );
                              },
                              icon: const Icon(Icons.visibility, size: 20),
                              label: const Text("Review"),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.deepOrange,
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
          ),
        ],
      ),
    );
  }
}
