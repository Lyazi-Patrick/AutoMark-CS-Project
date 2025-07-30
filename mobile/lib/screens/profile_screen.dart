import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isSaving = false;
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    // Load from Firestore if available
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        nameController.text = data['displayName'] ?? user?.displayName ?? '';
        emailController.text = data['email'] ?? user?.email ?? '';
        phoneController.text = data['phone'] ?? '';
        _profileImageUrl = data['photoUrl'];
      });
    } else {
      setState(() {
        nameController.text = user?.displayName ?? '';
        emailController.text = user?.email ?? '';
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
        _profileImageUrl = null; // Clear old URL if uploading new image
      });
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
        _profileImageUrl = null;
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user!.uid}.jpg');
      
      await ref.putFile(_profileImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!formKey.currentState!.validate() || user == null) return;

    setState(() => isSaving = true);

    try {
      final newName = nameController.text.trim();
      final newEmail = emailController.text.trim();
      final newPhone = phoneController.text.trim();

      // Upload image if selected
      final imageUrl = await _uploadProfileImage();

      // Update user profile
      await user!.updateDisplayName(newName);
      if (newEmail != user!.email) {
        await user!.verifyBeforeUpdateEmail(newEmail);
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({
            'displayName': newName,
            'email': newEmail,
            'phone': newPhone,
            'photoUrl': imageUrl ?? _profileImageUrl,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Reload user data
      await user!.reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _profileImage != null
                ? FileImage(_profileImage!) as ImageProvider
                : _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
            child: _profileImage == null && _profileImageUrl == null
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please sign in to view profile")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _updateProfile,
            tooltip: 'Save Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(child: _buildProfileImage()),
              const SizedBox(height: 30),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'Saving...' : 'Save Profile'),
                  onPressed: isSaving ? null : _updateProfile,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.green),
                title: const Text("Account Status"),
                subtitle: Text(user!.emailVerified
                    ? "Verified"
                    : "Not verified (check your email)"),
                trailing: !user!.emailVerified
                    ? TextButton(
                        onPressed: () async {
                          await user!.sendEmailVerification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Verification email sent!")),
                          );
                        },
                        child: const Text("Verify"),
                      )
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.blue),
                title: const Text("Account Security"),
                trailing: TextButton(
                  onPressed: () {
                    // Add password reset functionality
                    FirebaseAuth.instance.sendPasswordResetEmail(
                        email: user!.email!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Password reset email sent!")),
                    );
                  },
                  child: const Text("Reset Password"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}