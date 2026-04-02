class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String imageUrl;
  final String about;
  final String hospital;
  final List<String> availableTimes;
  final double rating;
  final double price;
  final int experienceYears;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.imageUrl,
    required this.about,
    required this.hospital,
    required this.availableTimes,
    required this.rating,
    required this.price,
    required this.experienceYears,
  });

  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
        id: j['id'] as String,
        name: j['name'] as String,
        specialty: j['specialty'] as String,
        imageUrl: j['image_url'] as String? ?? '',
        about: j['about'] as String? ?? '',
        hospital: j['hospital'] as String? ?? '',
        availableTimes: List<String>.from(j['available_times'] as List? ?? []),
        rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        experienceYears: (j['experience_years'] as num?)?.toInt() ?? 0,
      );
}
