import 'dart:typed_data';

/// A photo a try-on preview is made from: one of Clothsy's model photos, or
/// the shopper's own (Blueprint section 35).
class TryOnPhoto {
  final String id;
  final String label;

  /// Where to load the photo from (a signed URL for private shopper photos).
  final String imageUrl;

  /// The photo itself, when it only exists on this device (mock flavor).
  final Uint8List? bytes;
  final bool isPreset;
  final DateTime createdAt;

  /// When a shopper photo is deleted automatically (retention period).
  final DateTime? expiresAt;

  const TryOnPhoto({
    required this.id,
    required this.label,
    required this.imageUrl,
    this.bytes,
    this.isPreset = false,
    required this.createdAt,
    this.expiresAt,
  });

  TryOnPhoto copyWith({
    String? id,
    String? label,
    String? imageUrl,
    Uint8List? bytes,
    bool? isPreset,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return TryOnPhoto(
      id: id ?? this.id,
      label: label ?? this.label,
      imageUrl: imageUrl ?? this.imageUrl,
      bytes: bytes ?? this.bytes,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
