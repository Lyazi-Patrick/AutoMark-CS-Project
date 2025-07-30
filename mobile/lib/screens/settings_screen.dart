import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_navbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailSent = false;

  Future<void> _resetPasswordByEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No email associated with this account.")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => _emailSent = true);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Reset Email Sent"),
          content: Text("We sent a password reset link to:\n$email"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending email: $e")),
      );
    }
  }

  void _changePasswordInApp(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                final email = user?.email;
                final currentPass = currentPassController.text.trim();
                final newPass = newPassController.text.trim();

                if (user == null || email == null) throw "No logged in user.";
                if (newPass.length < 6) throw "New password must be at least 6 characters.";

                final cred = EmailAuthProvider.credential(email: email, password: currentPass);
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newPass);

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password updated successfully")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed: $e")),
                );
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;
    await user.reload();

    if (user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email already verified.")),
      );
    } else {
      await user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification email sent!")),
      );
    }

    setState(() {}); // Refresh
  }

 Future<void> _deleteAccount(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  final email = user?.email;

  if (user == null || email == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No user is currently signed in.")),
    );
    return;
  }

  final passwordController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Confirm Account Deletion"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Please enter your password to confirm deletion."),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password"),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final cred = EmailAuthProvider.credential(
      email: email,
      password: passwordController.text.trim(),
    );

    // 🔒 Re-authenticate first
    await user.reauthenticateWithCredential(cred);

    // ✅ Now delete the account
    await user.delete();

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to delete account: $e")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'Unknown';
    final isVerified = user?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Settings"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.email),
            title: const Text("Email"),
            subtitle: Text(
              "$userEmail (${isVerified ? "Verified" : "Unverified"})",
              style: TextStyle(color: isVerified ? Colors.green : Colors.red),
            ),
          ),

          if (!isVerified)
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text("Verify Email"),
              onTap: () => _verifyEmail(context),
            ),

          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text("Reset Password via Email"),
            onTap: _emailSent ? null : () => _resetPasswordByEmail(context),
            subtitle: _emailSent ? const Text("Link already sent") : null,
          ),

          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text("Change Password In-App"),
            onTap: () => _changePasswordInApp(context),
          ),

          const Divider(height: 30),
          const Text("Danger Zone", style: TextStyle(fontSize: 18, color: Colors.red)),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Delete My Account", style: TextStyle(color: Colors.red)),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
// Ensure the class name here matches the one in bottom_navbar.dart
bottomNavigationBar: const AutoMarkBottomNav(currentIndex: 4),
    );
  }
}

class AutoMarkBottomNav extends StatelessWidget {
  final int currentIndex;
  const AutoMarkBottomNav({Key? key, required this.currentIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Replace with your actual BottomNavigationBar implementation
    return BottomNavigationBar(
      currentIndex: currentIndex,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: (index) {
        // Handle navigation logic here
      },
    );
  }
}