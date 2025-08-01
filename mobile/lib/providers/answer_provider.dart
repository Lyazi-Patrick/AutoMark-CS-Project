import 'package:flutter/material.dart';

/// Model representing each answer in the answer Key.
class AnswerEntry {
  final String type; // 'Objective', 'Keyword', or 'Essay'
  final String answer;
  final List<String> keywords;
  final double weight; // Defaults to 1.0
  final bool useAI;    // If true, only AI should grade this answer

  AnswerEntry({
    required this.type,
    this.answer = '',
    this.keywords = const [],
    this.weight = 1.0,
    this.useAI = false,
  });

  List<String> get correctAnswers => keywords.isNotEmpty ? keywords : [answer];

  // Creates an AnswerEntry from JSON data
  factory AnswerEntry.fromJson(Map<String, dynamic> json) {
    return AnswerEntry(
      type: json['type'],
      answer: json['answer'] ?? '',
      keywords: List<String>.from(json['keywords'] ?? []),
      weight: (json['weight'] is num) ? json['weight'].toDouble() : 1.0,
      useAI: json['useAI'] ?? false,
    );
  }

  // Converts the AnswerEntry to JSON format
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'answer': answer,
      'keywords': keywords,
      'weight': weight,
      'useAI': useAI,
    };
  }
}

/// Provider class for managing answer entries
class AnswerProvider extends ChangeNotifier {
  final List<AnswerEntry> _entries = [];

  /// Returns an unmodifiable list of entries
  List<AnswerEntry> get entries => List.unmodifiable(_entries);

  /// Loads entries from JSON data.
  void loadFromJson(List<dynamic> jsonList) {
    _entries.clear();
    _entries.addAll(jsonList.map((e) => AnswerEntry.fromJson(e)));
    notifyListeners();
  }

  /// Adds a new entry.
  void addEntry(AnswerEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }

  /// Removes an entry at the specified index
  void removeEntry(int index) {
    if (index >= 0 && index < _entries.length) {
      _entries.removeAt(index);
      notifyListeners();
    }
  }

  /// Clears all entries
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Converts all entries to JSON format
  List<Map<String, dynamic>> toJsonList() {
    return _entries.map((e) => e.toJson()).toList();
  }
}
