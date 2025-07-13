import 'package:flutter/material.dart';
import 'marking_guide_screen.dart'; // Make sure this file exists

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('AutoMark'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.school, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to AutoMark',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Choose what you want to do',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            MenuButton(
              text: 'Upload Marking Guide',
              icon: Icons.upload_file,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MarkingGuideScreen()),
                );
              },
            ),
            MenuButton(
              text: 'Upload Exam Script',
              icon: Icons.description,
              onTap: () {
                // TODO: Navigate to exam script screen
              },
            ),
            MenuButton(
              text: 'View Results',
              icon: Icons.assignment_turned_in,
              onTap: () {
                // TODO: Navigate to results screen
              },
            ),
            MenuButton(
              text: 'Settings / About',
              icon: Icons.settings,
              onTap: () {
                // TODO: Navigate to settings screen
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const MenuButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.blueAccent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
