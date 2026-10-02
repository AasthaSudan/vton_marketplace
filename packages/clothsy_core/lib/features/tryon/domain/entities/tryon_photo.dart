class TryOnPhoto {
  final String id;
  final String label;
  final String imageUrl;
  final bool isPreset;
  final DateTime createdAt;

  const TryOnPhoto({
    required this.id,
    required this.label,
    required this.imageUrl,
    this.isPreset = false,
    required this.createdAt,
  });

  TryOnPhoto copyWith({
    String? id,
    String? label,
    String? imageUrl,
    bool? isPreset,
    DateTime? createdAt,
  }) {
    return TryOnPhoto(
      id: id ?? this.id,
      label: label ?? this.label,
      imageUrl: imageUrl ?? this.imageUrl,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
