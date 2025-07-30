class AnswerEntry {
  String question;
  String modelAnswer;
  int marks;

  AnswerEntry({
    required this.question,
    required this.modelAnswer,
    required this.marks,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'modelAnswer': modelAnswer,
        'marks': marks,
      };

  factory AnswerEntry.fromJson(Map<String, dynamic> json) => AnswerEntry(
        question: json['question'] ?? '',
        modelAnswer: json['modelAnswer'] ?? '',
        marks: (json['marks'] as num?)?.toInt() ?? 1, // Default fallback
      );
}
