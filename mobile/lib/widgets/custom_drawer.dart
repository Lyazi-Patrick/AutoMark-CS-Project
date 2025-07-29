import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/icons/bluetick.png', height: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'AutoMark',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart Script Grading',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // Navigation Links (all fixed to push normally)
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("History"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text("Downloads"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/downloads');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text("About"),
              onTap: () {
               showAboutDialog(
                  context: context,
                  applicationName: 'AutoMark',
                  applicationVersion: 'v1.0.0',
                  applicationIcon: Image.asset('assets/icons/bluetick.png', height: 40),
                  applicationLegalese: '© 2025 Group 27 - Makerere University',
                  children: [
                    const SizedBox(height: 10),
                    const Text("AutoMark is an AI-powered app that helps lecturers quickly and accurately grade scanned exam scripts."),
                    const SizedBox(height: 10),
                    const Text("Developed by Group 27 as part of the Computer Science  Project."),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse('https://automarking.netlify.app/');
                        if (!await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        )) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Could not launch the website")),
                          );
                        }
                      },
                      child: const Text(
                        'Visit our website',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const Spacer(),

            //  Logout Confirmation
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  // TODO: Clear any session data if needed

                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                } else {
                  Navigator.pop(context); // Close drawer
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}