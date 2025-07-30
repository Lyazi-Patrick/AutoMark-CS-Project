import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/bottom_navbar.dart';
import '../widgets/custom_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? displayName;
  bool isPremium = false;
  bool isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchStats();
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (userDoc.exists && userDoc.data() != null) {
      setState(() {
        displayName = userDoc.data()!['name'] ?? user.email;
        isPremium = userDoc.data()!['isPremium'] ?? false;
        isLoadingUser = false;
      });
    } else {
      setState(() {
        displayName = user.email;
        isLoadingUser = false;
      });
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("HOME"),
        centerTitle: true,
      ),
      drawer: const CustomDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await dashboardProvider.fetchStats();
            await _loadUserData();
          },
          child: dashboardProvider.isLoading || isLoadingUser
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Welcome, ${displayName ?? 'Lecturer'} 👋",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text("Here’s your marking summary",
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatCard(
                      title: "Unmarked Scripts",
                      value: dashboardProvider.unmarked.toString(),
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                      onTap: () => Navigator.pushNamed(context, '/unmarked'),
                    ),
                    _buildStatCard(
                      title: "Marked Scripts",
                      value: dashboardProvider.marked.toString(),
                      icon: Icons.task_alt,
                      color: Colors.green,
                      onTap: () => Navigator.pushNamed(context, '/marked_scripts'),
                    ),
                    _buildStatCard(
                      title: "Answer Key",
                      value: dashboardProvider.answerKeyAvailable ? "Available" : "Not Found",
                      icon: Icons.key,
                      color: dashboardProvider.answerKeyAvailable ? Colors.blue : Colors.red,
                      onTap: () async {
                        await Navigator.pushNamed(context, '/answer_key');
                        await dashboardProvider.fetchStats();
                      },
                    ),
                    _buildStatCard(
                      title: "Total Submissions",
                      value: dashboardProvider.total.toString(),
                      icon: Icons.bar_chart,
                      color: Colors.purple,
                      onTap: () => Navigator.pushNamed(context, '/result'),
                    ),

                    // Only show the Premium Card if not premium
                    if (!isPremium)
                      _buildStatCard(
                        title: "Upgrade to Premium",
                        value: "Unlock all features",
                        icon: Icons.workspace_premium,
                        color: Colors.amber,
                        onTap: () => Navigator.pushNamed(context, '/payments'),
                      ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 0),
    );
  }
}
