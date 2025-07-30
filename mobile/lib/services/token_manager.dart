import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TokenManager {
  String? _accessToken;
  DateTime? _expiryTime;

  final String baseUrl = 'https://sandbox.momodeveloper.mtn.com';
  final String subscriptionKey = dotenv.env['SUBSCRIPTION_KEY']!;
  final String userId = dotenv.env['UUID']!;
  final String apiKey = dotenv.env['API_KEY']!;

  Future<String> getValidToken() async {
    if (_accessToken != null && _expiryTime != null) {
      if (DateTime.now().isBefore(_expiryTime!)) {
        return _accessToken!;
      }
    }
    return await _refreshToken();
  }

  Future<String> _refreshToken() async {
    String credentials = base64Encode(utf8.encode('$userId:$apiKey'));

    final response = await http.post(
      Uri.parse('$baseUrl/collection/token/'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Ocp-Apim-Subscription-Key': subscriptionKey,
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      _accessToken = body['access_token'];
      _expiryTime = DateTime.now().add(Duration(seconds: body['expires_in'] ?? 3600));
      return _accessToken!;
    } else {
      throw Exception('Failed to refresh token: ${response.statusCode}');
    }
  }
}
// to be continued
