import 'package:http/http.dart' as http;
import 'dart:convert';

class AIMarkingService {
  static const String _apiKey = '';
  static const String _url = 'https://api.cohere.ai/v1/generate';

  //Sends a list of question/answer pairs to Cohere and returns the marking result as a string.
  // Each pair should be a map with 'question' and 'answer' keys.
  static Future<String> markAnswersWithAI(
    List<Map<String, String>> qaPairs,
  ) async {
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
      'Cohere-Version': '2022-12-06',
    };
    String prompt =
        'Mark the following answers. For each, give a mark out of 1 and a short feedback. Format: Q: ... A: ... Mark: ... Feedback: ...\n';
    for (var pair in qaPairs) {
      prompt += 'Q: ${pair['question']}\nA: ${pair['answer']}\n';
    }
    final body = jsonEncode({
      'model': 'command',
      'prompt': prompt,
      'max_tokens': 200 * qaPairs.length,
    });
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['generations'][0]['text'];
      } else {
        return 'Error: \\n${response.body}';
      }
    } catch (e) {
      return 'Exception: $e';
    }
  }
}
