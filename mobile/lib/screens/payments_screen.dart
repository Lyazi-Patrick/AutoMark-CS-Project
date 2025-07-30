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
  bool isPremium = false; // This will later be fetched from Firestore or API

void _startPaymentProcess() async {
  try {
    final tokenManager = TokenManager();
    final momoService = MomoService(
      tokenManager: tokenManager,
      subscriptionKey: dotenv.env['SUBSCRIPTION_KEY']!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Starting payment...")),
    );

    // Use real values here or UI inputs:
    final transactionId = await momoService.requestToPay(
      amount: '1000', // e.g. UGX 1000
      currency: 'EUR', // Sandbox uses EUR, check if you can switch to UGX in production
      externalId: '123456', // Your internal transaction ID
      payerNumber: '46733123454', // The payer’s MTN MoMo phone number
      payerMessage: 'Thanks for upgrading!',
      payeeNote: 'Payment for premium plan',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment initiated. Transaction ID: $transactionId")),
    );

    setState(() {
      isPremium = true;
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment failed: $e")),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upgrade to Premium"),
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.green,
                ),
              ),
            )
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
