import 'package:cloud_firestore/cloud_firestore.dart';

// NEW: Helper to calculate average percentage from a list of Firestore docs
num calculateAveragePercentage(List docs) {
  if (docs.isEmpty) return 0;
  final totalPercent = docs.fold<num>(0, (sum, doc) {
    final data =
        doc is Map<String, dynamic>
            ? doc
            : (doc.data() as Map<String, dynamic>);
    final score = (data['score'] is num) ? data['score'] as num : 0;
    final total = (data['total'] is num) ? data['total'] as num : 0;
    return sum + (total > 0 ? (score / total) * 100 : 0);
  });
  return totalPercent / docs.length;
}

// NEW: Shared query for marked scripts
Query getMarkedScriptsQuery() {
  return FirebaseFirestore.instance
      .collection('scripts')
      .where('status', isEqualTo: 'marked')
      .orderBy('timestamp', descending: true);
}
