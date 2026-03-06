class Patient {
  final String id;
  final String doctorId;
  final String name;
  final String sex;
  final String age;
  final String allergies;
  final String symptoms;
  final String preExistingConditions;

  Patient({
    required this.id,
    required this.doctorId,
    required this.name,
    required this.sex,
    required this.age,
    required this.allergies,
    required this.symptoms,
    required this.preExistingConditions,
  });

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['_id'] ?? '',
        doctorId: json['doctor_id'] ?? '',
        name: json['name'] ?? '',
        sex: json['sex'] ?? '',
        age: json['age']?.toString() ?? '',
        allergies: json['allergies'] ?? '',
        symptoms: json['symptoms'] ?? '',
        preExistingConditions: json['pre_existing_conditions'] ?? '',
      );
}
