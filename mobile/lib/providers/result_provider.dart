import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/answer_entry.dart';
import '../utils/grading_logic.dart'; // Updated grading logic with autoGradeAnswers.

class ResultProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get results => _results;
  bool get isLoading => _isLoading;

  double get averageScore {
    if (_results.isEmpty) return 0.0;
    final total = _results.fold<double>(
      0.0,
      (sum, r) => sum + ((r['score'] ?? 0) as num).toDouble(),
    );
    return total / _results.length;
  }

  int get totalSubmissions => _results.length;

  /// Fetch results from Firestore
  Future<void> fetchResults() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('results')
          .orderBy('timestamp', descending: true)
          .get();

      _results.clear();
      _results.addAll(snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'score': toInt(data['score']),
          'total': toInt(data['total']),
          'percentage': (data['percentage'] ?? "0.0").toString(),
          'timestamp': data['timestamp'],
          'method': data['method'] ?? 'auto',
          'details': data['details'] ?? []
          };
  }).toList());

    } catch (e) {
      debugPrint('❌ Failed to fetch results: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Grade using AutoMark fallback (no AI), using updated logic
  void calculateAutoMarkScore(List<String> studentAnswers, List<AnswerEntry> correctAnswers) {
    final answerKey = correctAnswers.map((e) => e.toJson()).toList();

    final result = autoGradeAnswers(
      studentAnswers: studentAnswers,
      answerKey: answerKey,
    );

    _results.insert(0, {
      'name': 'Anonymous',
      'score': result['totalScore'],
      'total': result['totalPossible'],
      'percentage': result['percentage'],
      'timestamp': Timestamp.now(),
      'method': 'automark',
      'details': result['details'], // Can be used for feedback review
    });

    notifyListeners();
  }

  /// Set result directly (for AI grading or when score is pre-calculated)
  void setAIResult({
    required int score,
    required int total,
    required String percentage,
    required List<Map<String, dynamic>> details,
    required String studentName,
  }) {
    _results.insert(0, {
      'name': studentName.isNotEmpty ? studentName : 'Anonymous',
      'score': score,
      'total': total,
      'percentage': percentage,
      'timestamp': Timestamp.now(),
      'method': 'aimark',
      'details': details,
    });

    notifyListeners();
  }

  /// Get result by student name
  /// Get result by student name
  Map<String, dynamic> getStudentResultByName(String name) {
    return _results.firstWhere(
      (r) => r['name'] == name,
      orElse: () => {'score': 0, 'total': 0, 'percentage': '0.0'},
    );
  }

  /// Clear results (reset)
  void clear() {
    _results.clear();
    notifyListeners();
  }
  int toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
}
}
