import 'dart:math';

/// Computes a simple similarity score between two strings (0.0 to 1.0)
double stringSimilarity(String a, String b) {
  final aTokens =
      a.toLowerCase().split(RegExp(r'\W+')).where((t) => t.isNotEmpty).toSet();
  final bTokens =
      b.toLowerCase().split(RegExp(r'\W+')).where((t) => t.isNotEmpty).toSet();
  if (aTokens.isEmpty || bTokens.isEmpty) return 0.0;
  final intersection = aTokens.intersection(bTokens).length;
  final union = aTokens.union(bTokens).length;
  return intersection / union;
}

/// Finds the best matching answer key index for a given student question.
int? findBestMatchIndex(
  String studentQ,
  List<dynamic> answerKey,
  Set<int> usedIndexes, {
  double threshold = 0.5,
}) {
  double bestScore = 0.0;
  int? bestIdx;
  for (int i = 0; i < answerKey.length; i++) {
    if (usedIndexes.contains(i)) continue;
    final keyQ = answerKey[i]['question'] ?? '';
    final score = stringSimilarity(studentQ, keyQ);
    if (score > bestScore && score >= threshold) {
      bestScore = score;
      bestIdx = i;
    }
  }
  return bestIdx;
}

/// Parses raw answer text into a list of {question, answer} maps (expects Q: ...\nA: ... format)
List<Map<String, String>> parseStudentQAPairs(String rawText) {
  final lines = rawText.split(RegExp(r'[\n\r]+'));
  List<Map<String, String>> pairs = [];
  String? currentQ;
  for (final line in lines) {
    if (line.trim().toUpperCase().startsWith('Q:')) {
      currentQ = line.substring(2).trim();
    } else if (line.trim().toUpperCase().startsWith('A:') && currentQ != null) {
      pairs.add({'question': currentQ, 'answer': line.substring(2).trim()});
      currentQ = null;
    }
  }
  return pairs;
}

/// Grades answers by matching student questions to answer key questions using similarity.
int gradeAnswersQAMatch(
  List<Map<String, String>> studentQAPairs,
  List<dynamic> answerKey,
) {
  int score = 0;
  Set<int> usedIndexes = {};
  for (final pair in studentQAPairs) {
    final idx = findBestMatchIndex(
      pair['question'] ?? '',
      answerKey,
      usedIndexes,
    );
    if (idx != null) {
      final correct =
          (answerKey[idx]['answer'] ?? '')
              .toString()
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .trim();
      final student =
          (pair['answer'] ?? '')
              .toLowerCase()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .trim();
      if (student == correct) {
        score += 1;
      }
      usedIndexes.add(idx);
    }
  }
  return score;
}

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

    String studentAnswer =
        studentAnswers[i]
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .trim();

    final key = answerKey[i];

    // Objective question (exact string match)
    if (key is String) {
      String correct =
          key.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

      if (studentAnswer == correct) {
        score += 1;
      }
    }
    // Keyword-based sentence (list of keywords)
    else if (key is List<String>) {
      List<String> keywords =
          key
              .map(
                (k) =>
                    k.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim(),
              )
              .toList();

      int matchedCount =
          keywords.where((keyword) => studentAnswer.contains(keyword)).length;

      if (matchedCount >= (keywords.length / 2).ceil()) {
        score += 1;
      }
    }
    // Weighted keyword question
    else if (key is Map<String, dynamic>) {
      double weight =
          key['weight'] is num ? (key['weight'] as num).toDouble() : 1.0;

      List<String> keywords =
          (key['keywords'] as List<dynamic>)
              .map(
                (k) =>
                    k
                        .toString()
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^\w\s]'), '')
                        .trim(),
              )
              .toList();

      int matchedCount =
          keywords.where((keyword) => studentAnswer.contains(keyword)).length;

      double matchRatio = matchedCount / keywords.length;

      if (matchRatio >= 0.5) {
        score += weight.toInt();
      }
    }
  }

  return score;
}
