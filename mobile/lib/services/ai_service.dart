import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:string_similarity/string_similarity.dart';

class AIService {
  // API Configuration
  final String? _openAiKey = dotenv.env['OPENAI_API_KEY'];
  final String? _groqKey = dotenv.env['GROQ_API_KEY'];
  final String _cohereKey = dotenv.env['COHERE_API_KEY'] ?? '6A1SzbNqSpmBRTfZzVMt8k7fj653gSy8TipWIzZO';

  final Uri _openAiUrl = Uri.parse("https://api.openai.com/v1/chat/completions");
  final Uri _groqUrl = Uri.parse("https://api.groq.com/openai/v1/chat/completions");
  final Uri _cohereUrl = Uri.parse("https://api.cohere.ai/v1/generate");

  /// Main method to extract and grade answers from student script
  Future<Map<String, dynamic>> extractAndGradeAnswers({
    required String studentScript,
    String? markingGuideText,
    bool useGroq = true,
  }) async {
    try {
      // Step 1: Extract marking guide structure if provided
      final List<Map<String, dynamic>> markingGuide = markingGuideText != null
          ? await _extractMarkingGuide(markingGuideText, useGroq: useGroq)
          : [];

      // Step 2: Extract student answers
      final Map<String, String> studentAnswers = await extractAnswersFromText(
        studentScript,
        guideQuestions: markingGuide.isNotEmpty 
            ? markingGuide.map((q) => q['question'].toString()).toList()
            : null,
        useGroq: useGroq,
      );

      // Step 3: Grade the answers
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

  /// Extract marking guide structure from text
  Future<List<Map<String, dynamic>>> extractMarkingGuideFromText(String text, {bool useGroq = true}) {
    return _extractMarkingGuide(text, useGroq: useGroq);
  }

  /// Grade script with existing marking guide
  Future<Map<String, dynamic>> gradeScript({
    required List<Map<String, dynamic>> answerKey,
    required Map<String, String> studentAnswers,
    bool useGroq = true,
  }) async {
    return _gradeWithMarkingGuide(
      markingGuide: answerKey,
      studentAnswers: studentAnswers,
      useGroq: useGroq,
    );
  }

  /// Grade answers when we have a marking guide
  Future<Map<String, dynamic>> _gradeWithMarkingGuide({
    required List<Map<String, dynamic>> markingGuide,
    required Map<String, String> studentAnswers,
    bool useGroq = true,
  }) async {
    int totalScore = 0;
    int totalPossible = 0;
    List<Map<String, dynamic>> questionDetails = [];

    for (var question in markingGuide) {
      final questionText = question['question'].toString();
      final modelAnswer = question['modelAnswer'].toString();
      final marks = (question['marks'] as num?)?.toInt() ?? 1;
      final studentAnswer = studentAnswers[questionText] ?? "";

      final gradeResult = await _hybridGradeAnswer(
        studentAnswer: studentAnswer,
        modelAnswer: modelAnswer,
        allocatedMarks: marks,
        useGroq: useGroq,
      );

      totalScore += (gradeResult['score'] as num).toInt();
      totalPossible += marks;

      questionDetails.add({
        'question': questionText,
        'modelAnswer': modelAnswer,
        'studentAnswer': studentAnswer,
        'score': gradeResult['score'],
        'maxScore': marks,
        'feedback': gradeResult['feedback'],
      });
    }

    return {
      'totalScore': totalScore,
      'totalPossible': totalPossible,
      'percentage': totalPossible > 0 ? (totalScore / totalPossible * 100).toStringAsFixed(1) : '0',
      'feedback': _generateOverallFeedback(totalScore, totalPossible),
      'details': questionDetails,
    };
  }

  /// Fallback grading when no marking guide is available
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

  /// Hybrid grading combining multiple techniques
  Future<Map<String, dynamic>> _hybridGradeAnswer({
    required String studentAnswer,
    required String modelAnswer,
    required int allocatedMarks,
    bool useGroq = true,
  }) async {
    // 1. Similarity Scoring
    final similarity = studentAnswer.similarityTo(modelAnswer);

    // 2. Keyword Matching
    final keywords = _extractKeywords(modelAnswer);
    final keywordScore = keywords.isEmpty 
        ? 0 
        : keywords.where((kw) => studentAnswer.toLowerCase().contains(kw.toLowerCase())).length / keywords.length;

    // 3. LLM Grading
    final llmResult = await _gradeWithLLM(
      studentAnswer: studentAnswer,
      modelAnswer: modelAnswer,
      allocatedMarks: allocatedMarks,
      useGroq: useGroq,
    );

    final llmScore = (llmResult['score'] as num).toDouble();

    // Combine scores (weighted average)
    final combinedScore = (0.4 * similarity + 0.3 * keywordScore + 0.3 * (llmScore / allocatedMarks)) * allocatedMarks;
    final finalScore = combinedScore.round().clamp(0, allocatedMarks);

    return {
      'score': finalScore,
      'feedback': llmResult['feedback'],
    };
  }

  /// Extract answers from OCR text
  Future<Map<String, String>> extractAnswersFromText(
    String rawText, {
    List<String>? guideQuestions,
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;

    if (apiKey == null) {
      throw Exception('API key not configured');
    }

    final guideSection = guideQuestions != null && guideQuestions.isNotEmpty
        ? "Here are the questions to look for:\n${guideQuestions.asMap().entries.map((e) => "${e.key + 1}. ${e.value}").join("\n")}\n\n"
        : "";

    final prompt = """
Extract student answers from exam text. Return JSON format:

{
  "1": "answer to question 1",
  "2": "answer to question 2"
}

$guideSection
Exam Text:
$rawText
""";

    final response = await _callLLMAPI(url, apiKey, prompt);
    return Map<String, String>.from(jsonDecode(response));
  }

  /// Extract marking guide structure from text
  Future<List<Map<String, dynamic>>> _extractMarkingGuide(
    String text, {
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;

    if (apiKey == null) {
      throw Exception('API key not configured');
    }

    final prompt = """
Extract marking guide as JSON array:

[
  {"question": "...", "modelAnswer": "...", "marks": X},
  {"question": "...", "modelAnswer": "...", "marks": X}
]

From:
$text
""";

    final response = await _callLLMAPI(url, apiKey, prompt);
    return List<Map<String, dynamic>>.from(jsonDecode(response));
  }

  /// Call LLM API (Groq or OpenAI)
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
      "temperature": 0.2,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception("API error: ${response.body}");
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  /// Grade with LLM
  Future<Map<String, dynamic>> _gradeWithLLM({
    required String studentAnswer,
    required String modelAnswer,
    required int allocatedMarks,
    bool useGroq = true,
  }) async {
    final url = useGroq ? _groqUrl : _openAiUrl;
    final apiKey = useGroq ? _groqKey : _openAiKey;

    if (apiKey == null) {
      throw Exception('API key not configured');
    }

    final prompt = """
Grade this answer (0-$allocatedMarks) and provide feedback. Return JSON:

{
  "score": X,
  "feedback": "..."
}

Model Answer:
$modelAnswer

Student Answer:
$studentAnswer
""";

    final response = await _callLLMAPI(url, apiKey, prompt);
    return jsonDecode(response);
  }

  /// Call Cohere API (fallback)
  Future<String> _callCohereAPI(String text) async {
    final headers = {
      'Authorization': 'Bearer $_cohereKey',
      'Content-Type': 'application/json',
      'Cohere-Version': '2022-12-06',
    };

    final prompt = """
Analyze this exam script and provide marks and feedback for each question you identify.
Format each as: Q: [question] A: [answer] Mark: X/Y Feedback: [feedback]

Script:
$text
""";

    final body = jsonEncode({
      'model': 'command',
      'prompt': prompt,
      'max_tokens': 1000,
      'temperature': 0.3,
    });

    final response = await http.post(_cohereUrl, headers: headers, body: body);

    if (response.statusCode != 200) {
      throw Exception("Cohere API error: ${response.body}");
    }

    final data = jsonDecode(response.body);
    return data['generations'][0]['text'];
  }

  /// Helper methods
  List<String> _extractKeywords(String text) {
    final words = text.split(RegExp(r'[\s,.]+')).map((w) => w.toLowerCase()).toSet();
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
}