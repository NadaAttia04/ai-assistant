class Medicine {
  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final bool inStock;
  final bool requiresPrescription;
  final int quantityAvailable;
  final String? imageUrl;

  const Medicine({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.inStock,
    required this.requiresPrescription,
    required this.quantityAvailable,
    this.imageUrl,
  });

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? '',
        description: j['description'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0.0,
        inStock: j['in_stock'] as bool? ?? true,
        requiresPrescription: j['requires_prescription'] as bool? ?? false,
        quantityAvailable: (j['quantity_available'] as num?)?.toInt() ?? 0,
        imageUrl: j['image_url'] as String?,
      );
}
