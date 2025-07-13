import 'package:flutter/material.dart';

class MarkingGuideScreen extends StatelessWidget {
  const MarkingGuideScreen({super.key}); // <--- This must match what you called

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marking Guide')),
      body: const Center(child: Text('Upload your Marking Guide here')),
    );
  }
}
