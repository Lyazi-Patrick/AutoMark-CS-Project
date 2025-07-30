import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardProvider extends ChangeNotifier {
  int marked = 0;
  int unmarked = 0;
  int total = 0;
  bool answerKeyAvailable = false;

  bool isLoading = false;

  Future<void> fetchStats() async {
    try {
      isLoading = true;
      notifyListeners();

      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        // No user logged in, clear statatistcs
        marked = 0;
        unmarked = 0;
        total = 0;
        answerKeyAvailable = false;
        isLoading = false;
        notifyListeners();
        return;
      }

      // Fetch user's scripts to be marked
      final scriptsSnapshot = await FirebaseFirestore.instance
          .collection('scripts')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      marked = scriptsSnapshot.docs.where((doc) => doc['status'] == 'marked').length;
      unmarked = scriptsSnapshot.docs.where((doc) => doc['status'] == 'unmarked').length;
      total = scriptsSnapshot.docs.length;

      // Check if user has at least one answer key
      final answerKeysSnapshot = await FirebaseFirestore.instance
          .collection('answer_keys')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      answerKeyAvailable = answerKeysSnapshot.docs.isNotEmpty;

    } catch (e) {
      print("Error fetching dashboard stats: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearStats() {
    marked = 0;
    unmarked = 0;
    total = 0;
    answerKeyAvailable = false;
    notifyListeners();
  }
}
