import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:string_similarity/string_similarity.dart';

class AIService {
  // === API Keys ====
  final String? _openAiKey = dotenv.env['OPENAI_API_KEY'];
  final String? _groqKey = dotenv.env['GROQ_API_KEY'];
  final String _cohereKey =
      dotenv.env['COHERE_API_KEY'] ??
      '6A1SzbNqSpmBRTfZzVMt8k7fj653gSy8TipWIzZO';

  // === API URLs ===
  final Uri _openAiUrl = Uri.parse(
    "https://api.openai.com/v1/chat/completions",
  );
  final Uri _groqUrl = Uri.parse(
    "https://api.groq.com/openai/v1/chat/completions",
  );
  final Uri _cohereUrl = Uri.parse("https://api.cohere.ai/v1/generate");

  // ========== PUBLIC METHODS ==========

  Future<Map<String, dynamic>> extractAndGradeAnswers({
    required String studentScript,
    String? markingGuideText,
    bool useGroq = true,
  }) async {
    try {
      final List<Map<String, dynamic>> markingGuide =
          markingGuideText != null
              ? await _extractMarkingGuide(markingGuideText, useGroq: useGroq)
              : [];

      final Map<String, String> studentAnswers = await extractAnswersFromText(
        studentScript,
        guideQuestions:
            markingGuide.isNotEmpty
                ? markingGuide.map((q) => q['question'].toString()).toList()
                : null,
        useGroq: useGroq,
      );

      if (markingGuide.isNotEmpty) {
        return await _gradeWithMarkingGuide(
          markingGuide: markingGuide,
          studentAnswers: studentAnswers,
          useGroq: useGroq,
        );
      } else {
        return await _gradeWithoutMarkingGuide(
          studentScript: studentScript,
          useGroq: useGroq,
        );
      }
    } catch (e) {
      return {
        'error': 'AI processing failed: ${e.toString()}',
        'score': 0,
        'feedback': 'Could not process answers due to an error',
      };
    }
  }

  Future<List<Map<String, dynamic>>> extractMarkingGuideFromText(
    String text, {
    bool useGroq = true,
  }) {
    return _extractMarkingGuide(text, useGroq: useGroq);
  }

  Future<Map<String, dynamic>> gradeScript({
    required List<Map<String, dynamic>> answerKey,
    required Map<String, String> studentAnswers,
    bool useGroq = true,
  }) {
    return _gradeWithMarkingGuide(
      markingGuide: answerKey,
      studentAnswers: studentAnswers,
      useGroq: useGroq,
    );
  }

  // ========== GRADING HELPERS ==========

  Future<Map<String, dynamic>> _gradeWithMarkingGuide({
    required List<Map<String, dynamic>> markingGuide,
    required Map<String, String> studentAnswers,
    bool useGroq = true,
  }) async {
    int totalScore = 0;
    int totalPossible = 0;
    List<Map<String, dynamic>> questionDetails = [];

    // Join all student answers into a single string for rawText checks
    final allStudentAnswersText = studentAnswers.values.join(" ").toLowerCase();

    for (var question in markingGuide) {
      final marks = (question['marks'] as num?)?.toInt() ?? 1;

      if (question.containsKey('question') &&
          question.containsKey('modelAnswer')) {
        final questionText = question['question'].toString();
        final modelAnswer = question['modelAnswer'].toString();
        final studentAnswer = studentAnswers[questionText] ?? "";

        final gradeResult = await _hybridGradeAnswer(
          studentAnswer: studentAnswer,
          modelAnswer: modelAnswer,
          allocatedMarks: marks,
          useGroq: useGroq,
        );

        totalScore += (gradeResult['score'] as num).toInt();

        questionDetails.add({
          'question': questionText,
          'modelAnswer': modelAnswer,
          'studentAnswer': studentAnswer,
          'score': gradeResult['score'],
          'maxScore': marks,
          'feedback': gradeResult['feedback'],
        });
      } else if (question.containsKey('rawText')) {
        final rawText = question['rawText'].toString().toLowerCase();

        // Simple substring check as fallback for raw entries
        final containsRaw = allStudentAnswersText.contains(rawText);

        final score = containsRaw ? marks : 0;
        totalScore += score;
        totalPossible += marks;

        questionDetails.add({
          'question': null,
          'modelAnswer': null,
          'studentAnswer': containsRaw ? rawText : "",
          'score': score,
          'maxScore': marks,
          'feedback':
              containsRaw
                  ? "Raw text matched in answer."
                  : "Raw text not found.",
        });

        // Continue to next since we handled rawText fallback
        continue;
      }
      totalPossible += marks;
    }

    return {
      'totalScore': totalScore,
      'totalPossible': totalPossible,
      'percentage':
          totalPossible > 0
              ? (totalScore / totalPossible * 100).toStringAsFixed(1)
              : '0',
      'feedback': _generateOverallFeedback(totalScore, totalPossible),
      'details': questionDetails,
    };
  }

  Future<String> extractTextWithFallback(String rawText) async {
    try {
      final extractedAnswers = await extractAnswersFromText(rawText);

      // Check if extractedAnswers is low quality or empty (you can refine this check)
      bool isLowQuality =
          extractedAnswers.isEmpty ||
          extractedAnswers.values
                  .where((v) => v.trim().split(' ').length >= 5)
                  .length <
              2;

      if (isLowQuality) {
        // Fallback to cleaned OCR text only
        return await cleanOcrText(rawText);
      }

      // Convert map to nicely formatted string preserving keys and spacing
      final buffer = StringBuffer();
      extractedAnswers.forEach((key, value) {
        buffer.writeln('$key:\n$value\n');
      });
      return buffer.toString().trim();
    } catch (e) {
      // AI extraction failed: fallback to clean OCR text
      return await cleanOcrText(rawText);
    }
  }

  Future<Map<String, dynamic>> _gradeWithoutMarkingGuide({
    required String studentScript,
    bool useGroq = true,
  }) async {
    try {
      final response = await _callCohereAPI(studentScript);
      return {
        'totalScore': 0,
        'totalPossible': 0,
        'percentage': '0',
        'feedback': response,
        'details': [],
      };
    } catch (e) {
      return {
        'error': 'Failed to grade script: ${e.toString()}',
        'score': 0,
        'feedback': 'Could not grade answers without marking guide',
      };
    }
  }

  Future<Map<String, dynamic>> _hybridGradeAnswer({
    required String studentAnswer,
    required String modelAnswer,
    required int allocatedMarks,
    bool useGroq = true,
  }) async {
    final similarity = studentAnswer.similarityTo(modelAnswer);

    final keywords = _extractKeywords(modelAnswer);
    final keywordScore =
        keywords.isEmpty
            ? 0
            : keywords
                    .where(
                      (kw) => studentAnswer.toLowerCase().contains(
                        kw.toLowerCase(),
                      ),
                    )
                    .length /
                keywords.length;

    final llmResult = await _gradeWithLLM(
      studentAnswer: studentAnswer,
      modelAnswer: modelAnswer,
      allocatedMarks: allocatedMarks,
      useGroq: useGroq,
    );

    final llmScore = (llmResult['score'] as num).toDouble();
    final combinedScore =
        (0.4 * similarity +
            0.3 * keywordScore +
            0.3 * (llmScore / allocatedMarks)) *
        allocatedMarks;
    final finalScore = combinedScore.round().clamp(0, allocatedMarks);

    return {'score': finalScore, 'feedback': llmResult['feedback']};
  }

  // ========== EXTRACTION HELPERS ==========

  Future<Map<String, String>> extractAnswersFromText(
    String rawText, {
    List<String>? guideQuestions,
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;
    if (apiKey == null) throw Exception('API key not configured');

    final guideSection =
        guideQuestions != null && guideQuestions.isNotEmpty
            ? "Here are the questions to find answers for:\n" +
                guideQuestions
                    .asMap()
                    .entries
                    .map((e) => "${e.key + 1}. ${e.value}")
                    .join("\n") +
                "\n\n"
            : "";

    final prompt = """
You are an assistant extracting detailed student answers from a handwritten exam OCR text.

Your task:
- For each question below, extract the student's full, exact answer from the OCR text.
- Maintain original spacing, indentation, and paragraph breaks exactly
- Do NOT shorten, summarize, or paraphrase answers.
- Return ONLY a JSON object mapping question numbers to their full extracted answers.
- If an answer is missing, return an empty string for that question.
- If multiple possible answers exist for a question, include all relevant text to fully capture the student's response.

Format:
{
  "1": "[full detailed answer]",
  "2": "[full detailed answer]",
  ...
}

Questions:
$guideSection

OCR Extracted Exam Script:
\"\"\"$rawText\"\"\"
""";

    final response = await _callLLMAPI(url, apiKey, prompt);
    return Map<String, String>.from(jsonDecode(response));
  }

  Future<List<Map<String, dynamic>>> _extractMarkingGuide(
    String text, {
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;
    if (apiKey == null) throw Exception('API key not configured');

    final prompt = """
The following text is a marking guide written by a teacher in any format.

Your job is to extract each question with:
- The question text
- Its ideal model answer
- The number of marks

Return as a JSON array of objects:
[
  {
    "question": "...",
    "modelAnswer": "...",
    "marks": 2
  },
  ...
]
""";

    final response = await _callLLMAPI(url, apiKey, prompt);
    print("🧠 Raw AI marking guide response:\n$response");

    try {
      final data = jsonDecode(response);

      if (data is! List) throw Exception('Expected a JSON array');

      final cleanList =
          data
              .whereType<Map<String, dynamic>>()
              .map((e) {
                final question = e['question']?.toString().trim();
                final answer = e['modelAnswer']?.toString().trim();
                final marksRaw = e['marks'];

                final marks =
                    (marksRaw is int)
                        ? marksRaw
                        : int.tryParse(marksRaw?.toString() ?? '') ?? 1;

                if (question == null ||
                    question.isEmpty ||
                    answer == null ||
                    answer.isEmpty) {
                  return null;
                }

                return {
                  'question': question,
                  'modelAnswer': answer,
                  'marks': marks,
                };
              })
              .whereType<Map<String, dynamic>>() // remove nulls
              .toList();

      print("✅ Cleaned marking guide: $cleanList");
      return cleanList;
    } catch (e) {
      print("❌ Failed to parse AI response: $e");
      throw Exception("Invalid marking guide format: ${e.toString()}");
    }
  }

  // ========== API CALLERS ==========

  Future<String> _callLLMAPI(Uri url, String apiKey, String prompt) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "model": "llama3-70b-8192",
      "messages": [
        {"role": "system", "content": "Return valid JSON only."},
        {"role": "user", "content": prompt},
      ],
      "temperature": 0.0,
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200)
      throw Exception("API error: ${response.body}");

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  Future<Map<String, dynamic>> _gradeWithLLM({
    required String studentAnswer,
    required String modelAnswer,
    required int allocatedMarks,
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;
    if (apiKey == null) throw Exception('API key not configured');

    final prompt = """
Grade this answer (0-$allocatedMarks) and provide feedback. Return JSON: { "score": X, "feedback": "..." }

Model Answer: $modelAnswer

Student Answer: $studentAnswer
""";

    final response = await _callLLMAPI(url, apiKey, prompt);
    return jsonDecode(response);
  }

  Future<String> cleanOcrText(String rawText, {bool useGroq = true}) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;
    if (apiKey == null) throw Exception('API key not configured');

    final prompt = """
You are an OCR cleanup assistant.

You will receive raw text extracted from handwritten exam scripts. 

Your task:
- Fix only obvious OCR errors (e.g., broken words due to scanning)
- Preserve all original words, including spelling, punctuation, and line breaks
- DO NOT remove or add any words
- DO NOT paraphrase, summarize, or interpret
- DO NOT add any explanations, comments, or extra text
- Return the text exactly as it should appear, with minimal changes only for clear OCR mistakes.

Raw OCR text:
\"\"\"$rawText\"\"\"
""";

    final response = await _callLLMAPI(url, apiKey, prompt);

    // Post-process response to remove unwanted text like intros or quotes
    return _postProcessCleanedText(response);
  }

  Future<String> _callCohereAPI(String text) async {
    final headers = {
      'Authorization': 'Bearer $_cohereKey',
      'Content-Type': 'application/json',
      'Cohere-Version': '2022-12-06',
    };

    final prompt = """
  Analyze this exam script and provide marks and feedback for each question you identify.
  Format each as:
  Q: [question]
  A: [answer]
  Mark: X/Y
  Feedback: [feedback]

  Script: $text
  """;

    final body = jsonEncode({
      'model': 'command',
      'prompt': prompt,
      'max_tokens': 1000,
      'temperature': 0.3,
    });

    final response = await http.post(_cohereUrl, headers: headers, body: body);
    if (response.statusCode != 200)
      throw Exception("Cohere API error: ${response.body}");

    final data = jsonDecode(response.body);
    return data['generations'][0]['text'];
  }

  // ========== UTILITIES ==========

  List<String> _extractKeywords(String text) {
    final words =
        text.split(RegExp(r'[\s,.]+')).map((w) => w.toLowerCase()).toSet();
    words.removeWhere((w) => w.length <= 3);
    return words.toList();
  }

  String _generateOverallFeedback(int score, int total) {
    final percent = (score / total) * 100;
    if (percent >= 80) return "Excellent work!";
    if (percent >= 60) return "Good effort, some revision needed.";
    if (percent >= 40) return "Fair attempt, revise concepts.";
    return "Needs improvement.";
  }

  String _postProcessCleanedText(String text) {
    final unwantedPatterns = <RegExp>[
      // Remove leading "here is the cleaned-up text:" (case-insensitive, optional spaces)
      RegExp(r'^\s*here is the cleaned[- ]?up text:?', caseSensitive: false),

      // Remove leading or trailing single or double quotes
      RegExp(r'''^[\'"]+|[\'"]+$'''),
    ];

    for (final pattern in unwantedPatterns) {
      text = text.replaceAll(pattern, '');
    }

    return text.trim();
  }
}
