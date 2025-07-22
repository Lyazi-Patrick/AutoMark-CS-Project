import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_navbar.dart';
import '../utils/pdf_generator.dart';
import '../widgets/custom_drawer.dart'; // ✅ Drawer import
import '../utils/marked_scripts_utils.dart'; // NEW: Import shared marked scripts utils

// NEW: Make ResultScreen a StatefulWidget to support search
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  double calculateAverage(List<QueryDocumentSnapshot> docs) {
    return calculateAveragePercentage(docs).toDouble();
  }

  Future<void> _generateReport(BuildContext context) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating PDF report...')));

      final snapshot =
          await FirebaseFirestore.instance
              .collection('results')
              .orderBy('timestamp', descending: true)
              .get();

      final docs = snapshot.docs;

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to generate report.')),
        );
        return;
      }

      await PDFGenerator.generateAndPrintReport();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report generated and saved successfully!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GRADE & STATS"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download Report',
            onPressed: () => _generateReport(context),
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar OUTSIDE StreamBuilder
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or student number...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              "Class Performance",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // StreamBuilder for results
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: getMarkedScriptsQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error fetching results: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No results available yet.'),
                    );
                  }

                  final avgScore = calculateAverage(docs).toStringAsFixed(1);

                  // Filter docs based on search query
                  final filteredDocs =
                      _searchQuery.isEmpty
                          ? docs
                          : docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name =
                                (data['name'] ?? '').toString().toLowerCase();
                            final number =
                                (data['number'] ?? '').toString().toLowerCase();
                            final query = _searchQuery.toLowerCase();
                            return name.contains(query) ||
                                number.contains(query);
                          }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Average Score: $avgScore%",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            "Submissions: ${docs.length}",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      const Text(
                        "Student Scores",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child:
                            filteredDocs.isEmpty
                                ? const Center(
                                  child: Text('No results match your search.'),
                                )
                                : ListView.separated(
                                  itemCount: filteredDocs.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final data =
                                        filteredDocs[index].data()
                                            as Map<String, dynamic>;
                                    final name = data['name'] ?? 'Unnamed';
                                    final number = data['number'] ?? '';
                                    final score = data['score'];
                                    final total = data['total'];

                                    String scoreStr;
                                    if (score is int ||
                                        (score is double && score % 1 == 0)) {
                                      scoreStr = score.toInt().toString();
                                    } else if (score is double) {
                                      scoreStr = score.toStringAsFixed(2);
                                    } else {
                                      scoreStr = score?.toString() ?? '';
                                    }
                                    String totalStr;
                                    if (total is int ||
                                        (total is double && total % 1 == 0)) {
                                      totalStr = total.toInt().toString();
                                    } else if (total is double) {
                                      totalStr = total.toStringAsFixed(2);
                                    } else {
                                      totalStr = total?.toString() ?? '';
                                    }
                                    // Calculate percentage
                                    String percentStr = '';
                                    final scoreNum =
                                        (score is num)
                                            ? score.toDouble()
                                            : double.tryParse(scoreStr) ?? 0.0;
                                    final totalNum =
                                        (total is num)
                                            ? total.toDouble()
                                            : double.tryParse(totalStr) ?? 0.0;
                                    if (totalNum > 0) {
                                      percentStr =
                                          ((scoreNum / totalNum) * 100)
                                              .toStringAsFixed(1) +
                                          '%';
                                    }

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.grey.shade100,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Name: $name',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (number.isNotEmpty)
                                                  Text(
                                                    'Student Number: $number',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            percentStr,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 2),
    );
  }
}
