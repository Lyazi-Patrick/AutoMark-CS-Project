/// Parses raw answer text into a clean list of answers (line by line).
List<String> parseAnswers(String rawText) {
  return rawText
      .trim()
      .split(RegExp(r'[\n\r]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Grades answers with support for:
/// - Objective questions (e.g. 'A', 'B', 'C').
/// - Sentence-based answers using keyword matching.
/// - Weighted answers (e.g. {'weight': 2, 'keywords': ['cell', 'nucleus']})
///
/// Parameters:
/// - [studentAnswers]: List of answers extracted from the student's script.
/// - [answerKey]: A list of correct answers. Each item can be:
///     - String (exact match)
///     - List<String> (keyword-based)
///     - Map<String, dynamic> (weighted keywords)
///
/// Returns:
/// - Integer score representing total correct answers.
int gradeAnswers(List<String> studentAnswers, List<dynamic> answerKey) {
  int score = 0;

  for (int i = 0; i < answerKey.length; i++) {
    if (i >= studentAnswers.length) continue;

    String studentAnswer = studentAnswers[i]
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();

    final key = answerKey[i];

    // Objective question (exact string match)
    if (key is String) {
      String correct = key
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim();

      if (studentAnswer == correct) {
        score += 1;
      }
    }

    // Keyword-based sentence (list of keywords)
    else if (key is List<String>) {
      List<String> keywords = key
          .map((k) => k
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .trim())
          .toList();

      int matchedCount = keywords
          .where((keyword) => studentAnswer.contains(keyword))
          .length;

      if (matchedCount >= (keywords.length / 2).ceil()) {
        score += 1;
      }
    }

    // Weighted keyword question
    else if (key is Map<String, dynamic>) {
      double weight = key['weight'] is num
          ? (key['weight'] as num).toDouble()
          : 1.0;

      List<String> keywords = (key['keywords'] as List<dynamic>)
          .map((k) => k
              .toString()
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .trim())
          .toList();

      int matchedCount = keywords
          .where((keyword) => studentAnswer.contains(keyword))
          .length;

      double matchRatio = matchedCount / keywords.length;

      if (matchRatio >= 0.5) {
        score += weight.toInt();
      }
    }
  }

  return score;
}
