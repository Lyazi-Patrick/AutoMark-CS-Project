import 'package:flutter/material.dart';

class AnswerProvider extends ChangeNotifier {
  List<String> _correctAnswers = [];

  List<String> get correctAnswers => _correctAnswers;

  void setAnswerKey(String input) {
    _correctAnswers = input.split(',').map((e) => e.trim().toUpperCase()).toList();
    notifyListeners();
  }

  void clearAnswers() {
    _correctAnswers.clear();
    notifyListeners();
  }
}