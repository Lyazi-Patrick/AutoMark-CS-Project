class AnswerEntry {
  String? question;
  String? modelAnswer;
  int? marks;
  String? rawText; // Fallback if structured extraction fails

  AnswerEntry({
    this.question,
    this.modelAnswer,
    this.marks,
    this.rawText,
  });

  Map<String, dynamic> toJson() => {
        if (question != null) 'question': question,
        if (modelAnswer != null) 'modelAnswer': modelAnswer,
        if (marks != null) 'marks': marks,
        if (rawText != null) 'rawText': rawText,
      };

  factory AnswerEntry.fromJson(Map<String, dynamic> json) => AnswerEntry(
        question: json['question'],
        modelAnswer: json['modelAnswer'],
        marks: (json['marks'] as num?)?.toInt(),
        rawText: json['rawText'],
      );

  bool get isStructured =>
      question != null && modelAnswer != null && marks != null;

  bool get isRaw => rawText != null && !isStructured;
}
