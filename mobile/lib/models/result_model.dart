class Result {
  final String id;
  final String studentName;
  final int score;
  final DateTime timestamp;

  Result({
    required this.id,
    required this.studentName,
    required this.score,
    required this.timestamp,
  });

  // Factory constructor to create a Result from Firestore document
  factory Result.fromMap(Map<String, dynamic> map, String docId) {
    return Result(
      id: docId,
      studentName: map['name'] ?? 'Unnamed',
      score: map['score'] ?? 0,
      timestamp: (map['timestamp'] is DateTime)
          ? map['timestamp']
          : (map['timestamp']?.toDate() ?? DateTime.now()),
    );
  }

  // Convert Result to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': studentName,
      'score': score,
      'timestamp': timestamp,
    };
  }
}