import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';
import '../providers/tryon_provider.dart';

class ModelPhotoPickerSheet extends ConsumerWidget {
  final Function(TryOnPhoto) onSelectPhoto;

  const ModelPhotoPickerSheet({super.key, required this.onSelectPhoto});

  static Future<void> show(
    BuildContext context,
    Function(TryOnPhoto) onSelectPhoto,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModelPhotoPickerSheet(onSelectPhoto: onSelectPhoto),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final presetsAsync = ref.watch(tryOnPresetsProvider);
    final session = ref.watch(tryOnNotifierProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Choose Your Model Photo',
                style: AppTypography.h3(color: colors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Your photo stays active across all outfits until changed.',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),

          presetsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, stack) => Center(
              child: Text(
                'Failed to load photos: $err',
                style: AppTypography.caption(color: colors.error),
              ),
            ),
            data: (presets) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: presets.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  // Custom photo upload card
                  if (index == 0) {
                    return PressableScale(
                      onTap: () {
                        Navigator.pop(context);
                        // Mock upload custom user photo
                        final customPhoto = TryOnPhoto(
                          id: 'user_uploaded_${DateTime.now().millisecondsSinceEpoch}',
                          label: 'My Custom Pose',
                          imageUrl:
                              'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
                          isPreset: false,
                          createdAt: DateTime.now(),
                        );
                        onSelectPhoto(customPhoto);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.primary.withOpacity(0.3),
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.accentSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                color: colors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Upload Mine',
                              style: AppTypography.bodyMedium(
                                weight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Camera or Gallery',
                              style: AppTypography.caption(
                                color: colors.textSecondary,
                              ).copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final photo = presets[index - 1];
                  final isSelected = session.selectedPhoto?.id == photo.id;

                  return PressableScale(
                    onTap: () {
                      Navigator.pop(context);
                      onSelectPhoto(photo);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.border,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: photo.imageUrl,
                            fit: BoxFit.cover,
                          ),
                          // Subtle bottom vignette
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.85),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(
                                photo.label,
                                style:
                                    AppTypography.caption(
                                      color: Colors.white,
                                    ).copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
