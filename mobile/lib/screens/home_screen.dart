import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart'; // ✅ Make sure this import is here
import '../utils/marked_scripts_utils.dart'; // NEW: Import shared marked scripts utils

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final scriptsSnapshot = await getMarkedScriptsQuery().get();

    final scripts = scriptsSnapshot.docs;
    final submissions = scripts.length;

    final average = calculateAveragePercentage(scripts);

    final lastStudent =
        submissions > 0
            ? scripts.first['name'] ?? 'Unnamed'
            : 'No submissions yet';

    return {
      'submissions': submissions,
      'average': average.toStringAsFixed(1),
      'lastStudent': lastStudent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HOME"),
        centerTitle: true,
        // No need for custom IconButton here, drawer icon comes automatically
      ),
      drawer: const CustomDrawer(), // ✅ This activates the ☰ menu
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset('assets/icons/bluetick.png', height: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'AutoMark',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              FutureBuilder<Map<String, dynamic>>(
                future: fetchDashboardStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final stats = snapshot.data!;
                  return Expanded(
                    child: ListView(
                      children: [
                        _buildStatCard(
                          "Total Submissions",
                          stats['submissions'].toString(),
                        ),
                        _buildStatCard("Average Score", "${stats['average']}%"),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 0),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
