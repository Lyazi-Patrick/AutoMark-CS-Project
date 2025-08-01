import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/answer_entry.dart';

class MarkingGuide {
  final String id;
  final String title;
  final List<AnswerEntry> entries;

  MarkingGuide({
    required this.id,
    required this.title,
    required this.entries,
  });

  factory MarkingGuide.fromJson(String id, Map<String, dynamic> json) {
    final answers = (json['answers'] as List<dynamic>? ?? []).map((e) {
      return AnswerEntry.fromJson(Map<String, dynamic>.from(e));
    }).toList();

    return MarkingGuide(
      id: id,
      title: json['title'] ?? 'Untitled',
      entries: answers,
    );
  }
}

class MarkingGuideProvider with ChangeNotifier {
  List<MarkingGuide> _allGuides = [];
  MarkingGuide? _selectedGuide;

  List<MarkingGuide> get allGuides => _allGuides;
  MarkingGuide? get selectedGuide => _selectedGuide;

  /// Loads all guides from Firestore (answer_keys collection).
  Future<void> fetchGuides() async {
    final snapshot = await FirebaseFirestore.instance.collection('answer_keys').get();

    _allGuides = snapshot.docs.map((doc) {
      return MarkingGuide.fromJson(doc.id, doc.data());
    }).toList();

    notifyListeners();
  }

  /// Select a guide for marking in the app
  void setSelectedGuide(MarkingGuide guide) {
    _selectedGuide = guide;
    notifyListeners();
  }

  /// Clear selected guide
  void clearSelection() {
    _selectedGuide = null;
    notifyListeners();
  }

  MarkingGuide? getGuideById(String id) {
  try {
    return _allGuides.firstWhere((g) => g.id == id);
  } catch (_) {
    return null;
  }
}
}
