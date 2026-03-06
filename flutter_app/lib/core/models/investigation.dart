class Investigation {
  final String id;
  final String patientId;
  final String text;
  final String? result;

  Investigation({
    required this.id,
    required this.patientId,
    required this.text,
    this.result,
  });

  factory Investigation.fromJson(Map<String, dynamic> json) => Investigation(
        id: json['_id'] ?? '',
        patientId: json['patient_id'] ?? '',
        text: json['text'] ?? '',
        result: json['result'],
      );
}
