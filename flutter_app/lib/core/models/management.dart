class Management {
  final String id;
  final String patientId;
  final String text;

  Management({
    required this.id,
    required this.patientId,
    required this.text,
  });

  factory Management.fromJson(Map<String, dynamic> json) => Management(
        id: json['_id'] ?? '',
        patientId: json['patient_id'] ?? '',
        text: json['text'] ?? '',
      );
}
