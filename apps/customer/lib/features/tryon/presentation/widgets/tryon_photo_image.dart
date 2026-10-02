import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';

/// Shows a try-on photo whether it lives on this device (just picked) or
/// behind a URL (model photos, signed URLs for stored shopper photos).
class TryOnPhotoImage extends StatelessWidget {
  final TryOnPhoto photo;
  final BoxFit fit;

  const TryOnPhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bytes = photo.bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: fit, gaplessPlayback: true);
    }
    return CachedNetworkImage(
      imageUrl: photo.imageUrl,
      fit: fit,
      placeholder: (context, _) => ColoredBox(color: colors.surfaceMuted),
      errorWidget: (context, _, _) => ColoredBox(
        color: colors.surfaceMuted,
        child: Icon(Icons.person_outline, color: colors.textSecondary),
      ),
    );
  }
}
