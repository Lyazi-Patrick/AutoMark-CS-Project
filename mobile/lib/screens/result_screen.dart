import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';
import '../utils/pdf_generator.dart';
import '../providers/dashboard_provider.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<QueryDocumentSnapshot> _results = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double calculateAverage(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    double total = docs.fold(0, (double sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final score = (data['score'] ?? 0).toDouble();
      final totalMarks = (data['total'] ?? 100).toDouble(); // Default to 100 if not specified
      final percentage = (score / totalMarks) * 100;
      return sum + percentage;
    });
    return total / docs.length;
  }

  Future<void> _loadInitialResults() async {
    setState(() {
      _results.clear();
      _lastDocument = null;
      _hasMore = true;
      _isLoading = true;
    });
    await _fetchResults();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchResults() async {
    if (!_hasMore) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingMore = true);

    Query query = FirebaseFirestore.instance
        .collection('results')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
      _results.addAll(snapshot.docs);
    }

    if (snapshot.docs.length < _pageSize) {
      _hasMore = false;
    }

    setState(() => _isLoadingMore = false);
  }

  Future<void> _generateReport() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF report...')),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('results')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .get();

      final docs = snapshot.docs;

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to generate report.')),
        );
        return;
      }

      await PDFGenerator.generateAndPrintReport(docs);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF report generated and saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    }
  }

  Future<void> _deleteSingleResult(String docId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('results').doc(docId).get();

      if (!docSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Result not found.')),
        );
        return;
      }

      final data = docSnapshot.data()!;

      // Prepare history entry
      final historyData = {
        ...data,
        'deletedAt': Timestamp.now(),
        'originalId': docId,
        'status': 'deleted',
        'type': 'result',
      };

      // Save to history first
      await FirebaseFirestore.instance.collection('history').doc(docId).set(historyData);

      // Delete from original collection
      await FirebaseFirestore.instance.collection('results').doc(docId).delete();

      setState(() {
        _results.removeWhere((doc) => doc.id == docId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Result moved to history.')),
      );

      await Provider.of<DashboardProvider>(context, listen: false).fetchStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to delete result: $e')),
      );
    }
  }

  List<QueryDocumentSnapshot> _filterResults() {
    if (_searchQuery.isEmpty) return _results;
    
    return _results.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final number = (data['number'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || number.contains(query);
    }).toList();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or student number...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildSummaryHeader(String avgScore) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Class Performance",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Average Score: $avgScore%", style: const TextStyle(fontWeight: FontWeight.w600)),
              Text("Submissions: ${_results.length}", style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 30),
          const Text("Student Scores", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildResultCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final name = data['name'] ?? 'Unnamed';
    final number = data['number'] ?? '';
    final score = (data['score'] ?? 0).toDouble();
    final total = (data['total'] ?? 100).toDouble();
    final percentage = (score / total * 100).toStringAsFixed(1);
    final method = data['method'] ?? 'manual';
    final feedback = data['feedback'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade100,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                if (number.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("Student No: $number", style: const TextStyle(fontSize: 14)),
                ],
                const SizedBox(height: 4),
                Text("Score: ${score.toStringAsFixed(score % 1 == 0 ? 0 : 2)}/${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)} ($percentage%)",
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text("Method: ${method.toUpperCase()}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("Feedback: $feedback",
                      style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPercentageColor(double.parse(percentage)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("$percentage%",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteSingleResult(doc.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 70) return Colors.green;
    if (percentage >= 50) return Colors.blue;
    if (percentage >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final filteredResults = _filterResults();
    final avgScore = calculateAverage(_results).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Results & Insights"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Summary',
            onPressed: _generateReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadInitialResults,
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadInitialResults,
                    child: _results.isEmpty
                        ? const Center(child: Text("No results available yet."))
                        : ListView.builder(
                            itemCount: filteredResults.isEmpty 
                                ? 2 // For header and "no results" message
                                : filteredResults.length + 1 + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildSummaryHeader(avgScore);
                              }
                              
                              if (filteredResults.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text("No results match your search."),
                                  ),
                                );
                              }
                              
                              if (_hasMore && index == filteredResults.length + 1) {
                                _fetchResults();
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              
                              final doc = filteredResults[index - 1];
                              return _buildResultCard(doc);
                            },
                          ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 2),
    );
  }
}