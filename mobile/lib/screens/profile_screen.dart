import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("No user logged in."))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/icons/bluetick.png'), // Replace with actual profile image logic later
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user.email ?? "No Email",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text("User ID: ${user.uid}"),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    label: const Text("Back to Home"),
                  )
                ],
              ),
            ),
    );
  }
}