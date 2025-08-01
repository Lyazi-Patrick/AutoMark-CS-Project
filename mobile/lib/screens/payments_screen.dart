import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/token_manager.dart';
import '../services/momo_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool isPremium = false; // This will later be fetched from Firestore or API.

  void _startPaymentProcess() async {
    try {
      final subscriptionKey = dotenv.env['SUBSCRIPTION_KEY'];
      if (subscriptionKey == null) {
        throw Exception('Missing SUBSCRIPTION_KEY in .env');
      }

      final tokenManager = TokenManager();
      final momoService = MomoService(
        tokenManager: tokenManager,
        subscriptionKey: subscriptionKey,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Starting payment...")));

      final transactionId = await momoService.requestToPay(
        amount: '1000',
        currency: 'EUR', // Use UGX in production only
        externalId: '123456',
        payerNumber: '256753123456', // Format: country code + number
        payerMessage: 'Thanks for upgrading!',
        payeeNote: 'Payment for premium plan',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment initiated. Transaction ID: $transactionId"),
        ),
      );

      setState(() {
        isPremium = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Payment failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upgrade to Premium")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Current Plan: ${isPremium ? 'Premium' : 'Free'}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "Premium Features:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const FeatureTile(text: "✅ Bulk Marking"),
            const FeatureTile(text: "✅ Analytics Dashboard"),
            const FeatureTile(text: "✅ Advanced PDF Reports"),
            const FeatureTile(text: "✅ Long-term Script Storage"),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: isPremium ? null : _startPaymentProcess,
                icon: const Icon(Icons.payment),
                label: const Text("Upgrade with MTN MoMo"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final String text;

  const FeatureTile({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
      title: Text(text),
    );
  }
}
