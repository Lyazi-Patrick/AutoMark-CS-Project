// Imports
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'token_manager.dart';

class MomoService {
  final TokenManager tokenManager;
  final String baseUrl = 'https://sandbox.momodeveloper.mtn.com';
  final String subscriptionKey;

  MomoService({required this.tokenManager, required this.subscriptionKey});

  Future<String> requestToPay({
    required String amount,
    required String currency,
    required String externalId,
    required String payerNumber,
    String payerMessage = 'Payment',
    String payeeNote = 'Payment from Flutter App',
  }) async {
    final accessToken = await tokenManager.getValidToken();
    final transactionId = Uuid().v4();

    final response = await http.post(
      Uri.parse('$baseUrl/collection/v1_0/requesttopay'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'X-Reference-Id': transactionId,
        'X-Target-Environment': 'sandbox',
        'Ocp-Apim-Subscription-Key': subscriptionKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        'externalId': externalId,
        'payer': {
          'partyIdType': 'MSISDN',
          'partyId': payerNumber,
        },
        'payerMessage': payerMessage,
        'payeeNote': payeeNote,
      }),
    );

    if (response.statusCode == 202) {
      return transactionId;
    } else {
      throw Exception('Payment request failed: ${response.statusCode} ${response.body}');
    }
  }
}
