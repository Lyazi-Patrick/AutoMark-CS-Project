import 'package:string_similarity/string_similarity.dart';

/// Fallback AutoMark grading logic (non-AI, no LLM call)
/// Uses similarity + simple keyword matching for local grading.
Map<String, dynamic> autoGradeAnswers({
  required List<String> studentAnswers,
  required List<Map<String, dynamic>> answerKey,
}) {
  int totalScore = 0;
  int totalPossible = 0;
  List<Map<String, dynamic>> details = [];

  for (int i = 0; i < answerKey.length; i++) {
    final item = answerKey[i];
    final question = item['question'];
    final modelAnswer = item['modelAnswer'];
    final marks = (item['marks'] as num?)?.toInt() ?? 1; // Default to 1 if null

    String studentAnswer = (i < studentAnswers.length) ? studentAnswers[i] : "";

    final cleanedStudentAnswer = _clean(studentAnswer);
    final cleanedModelAnswer = _clean(modelAnswer);

    // Simple similarity score using string_similarity package
    final similarity = cleanedStudentAnswer.similarityTo(cleanedModelAnswer);

    // Simple keyword matching
    final modelKeywords = modelAnswer.split(RegExp(r'[\s,.]+')).where((w) => w.length > 3).toList();
    final matchedKeywords = modelKeywords.where((kw) => cleanedStudentAnswer.contains(kw.toLowerCase())).length;
    final keywordRatio = (modelKeywords.isEmpty) ? 0.0 : (matchedKeywords / modelKeywords.length);

    // Score decision
    double rawScoreRatio = (0.5 * similarity) + (0.5 * keywordRatio);
    int awardedMarks = (rawScoreRatio * marks).round();

    totalScore += awardedMarks;
    totalPossible += marks;

    // Feedback
    final feedback = "Similarity: ${(similarity * 100).toStringAsFixed(1)}%, "
        "Keywords matched: ${(keywordRatio * 100).toStringAsFixed(1)}%. "
        "Score: $awardedMarks/$marks";

    details.add({
      "question": question,
      "modelAnswer": modelAnswer,
      "studentAnswer": studentAnswer,
      "allocatedMarks": marks,
      "score": awardedMarks,
      "feedback": feedback,
    });
  }

  return {
    "totalScore": totalScore,
    "totalPossible": totalPossible,
    "percentage": (totalPossible > 0) ? (totalScore / totalPossible * 100).toStringAsFixed(1) : "0.0",
    "details": details,
  };
}

/// Cleans a string: lowercases, removes punctuation and trims spaces.
String _clean(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .trim();
}
