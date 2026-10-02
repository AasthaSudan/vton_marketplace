import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:clothsy_core/core/constants/clothsy_copy.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/core/utils/currency_formatter.dart';
import 'package:clothsy_shop/features/cart/presentation/providers/cart_provider.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_shop/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:clothsy_core/shared/widgets/buttons/clothsy_icon_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/secondary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/shared/widgets/selectors/color_swatch_selector.dart';
import 'package:clothsy_core/shared/widgets/selectors/size_selector.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_session.dart';
import 'providers/tryon_provider.dart';
import 'tryon_history_screen.dart';
import 'widgets/before_after_slider.dart';
import 'widgets/model_photo_picker_sheet.dart';
import 'widgets/photo_guidance_sheet.dart';
import 'widgets/tryon_photo_image.dart';
import 'widgets/tryon_shimmer_loading.dart';

/// Clothsy AI Try-On (Blueprint section 35, fig. 27): pick a photo, confirm
/// the colour, see the AI preview, then choose a size and add to bag.
class TryonScreen extends ConsumerStatefulWidget {
  final String? initialProductId;

  const TryonScreen({super.key, this.initialProductId});

  @override
  ConsumerState<TryonScreen> createState() => _TryonScreenState();
}

class _TryonScreenState extends ConsumerState<TryonScreen> {
  bool _initializedProduct = false;
  String _selectedGarmentCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupInitialGarment();
    });
  }

  Future<void> _setupInitialGarment() async {
    if (_initializedProduct) return;
    _initializedProduct = true;

    final notifier = ref.read(tryOnNotifierProvider.notifier);
    final repo = ref.read(catalogRepositoryProvider);
    if (widget.initialProductId != null) {
      final p = await repo.getProductById(widget.initialProductId!);
      if (p != null && p.variants.isNotEmpty && mounted) {
        // Even an unsupported piece is selected, so we can explain gently.
        notifier.selectGarment(p);
        return;
      }
    }

    if (ref.read(tryOnNotifierProvider).selectedProduct != null) return;
    final all = await repo.getProducts();
    final eligible = all.where(
      (p) => p.isTryonEligible && p.variants.isNotEmpty,
    );
    if (eligible.isNotEmpty && mounted) notifier.selectGarment(eligible.first);
  }

  void _openPhotoGuidance() {
    PhotoGuidanceSheet.show(
      context,
      alreadyConsented: ref.read(tryOnNotifierProvider).hasConsented,
      onConsentGranted: () =>
          ref.read(tryOnNotifierProvider.notifier).grantConsent(),
      onCameraSelected: () => _pickOwnPhoto(ImageSource.camera),
      onGallerySelected: () => _pickOwnPhoto(ImageSource.gallery),
      onPresetSelected: _openModelPicker,
    );
  }

  Future<void> _pickOwnPhoto(ImageSource source) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } on PlatformException {
      if (!mounted) return;
      ClothsySnackbar.show(
        context,
        message:
            "We couldn't open your ${source == ImageSource.camera ? 'camera' : 'photos'}. "
            'Check the permission in your phone settings.',
        type: SnackbarType.error,
      );
      return;
    }
    if (file == null) return; // Closed the picker.

    final bytes = await file.readAsBytes();
    final error = await ref
        .read(tryOnNotifierProvider.notifier)
        .useOwnPhoto(bytes, file.mimeType ?? 'image/jpeg');
    if (!mounted) return;
    ClothsySnackbar.show(
      context,
      message: error ?? 'Your photo is ready. Pick a piece and try it on.',
      type: error == null ? SnackbarType.success : SnackbarType.error,
    );
  }

  void _openModelPicker() {
    ModelPhotoPickerSheet.show(
      context,
      onSelectPhoto: (photo) =>
          ref.read(tryOnNotifierProvider.notifier).selectPhoto(photo),
      onUseOwnPhoto: _openPhotoGuidance,
    );
  }

  Future<void> _generate({bool regenerate = false}) async {
    final session = ref.read(tryOnNotifierProvider);
    final photo = session.selectedPhoto;
    // The shopper's own photo needs consent; model photos do not.
    if (photo != null && !photo.isPreset && !session.hasConsented) {
      _openPhotoGuidance();
      return;
    }

    HapticFeedback.mediumImpact();
    final result = await ref
        .read(tryOnNotifierProvider.notifier)
        .generateTryOn(regenerate: regenerate);
    if (result != null && mounted) HapticFeedback.lightImpact();
  }

  Future<void> _chooseSizeAndAdd(TryOnSessionState session) async {
    final product = session.selectedProduct;
    final shown = session.selectedVariant;
    if (product == null || shown == null) return;

    final variant = await _SizeSheet.show(context, product, shown);
    if (variant == null || !mounted) return;
    ref.read(cartProvider.notifier).addToCart(product, variant);
    HapticFeedback.lightImpact();
    ClothsySnackbar.show(
      context,
      message: 'Added ${product.title} (${variant.size}) to your bag',
      type: SnackbarType.success,
    );
    context.go('/bag');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(tryOnNotifierProvider);
    final history = ref.watch(tryOnHistoryProvider);
    final catalogAsync = ref.watch(allProductsProvider);
    final presetsAsync = ref.watch(tryOnPresetsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.tryOnSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: colors.tryOn, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Clothsy AI Try-On',
                style: AppTypography.h3(color: colors.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.history_outlined, size: 22),
                tooltip: 'Your looks',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TryOnHistoryScreen(),
                    ),
                  );
                },
              ),
              if (history.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${history.length}',
                      style: AppTypography.caption(
                        color: colors.onPrimary,
                        weight: FontWeight.w700,
                      ).copyWith(fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: 'Photo tips & privacy',
            onPressed: _openPhotoGuidance,
          ),
        ],
      ),
      body: Column(
        children: [
          // AI credits & quick status banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.tryOnSoft.withOpacity(0.7),
                    colors.surfaceMuted,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.tryOn.withOpacity(0.18),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: colors.tryOn.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: colors.tryOn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${session.remainingCredits} ',
                            style: AppTypography.caption(
                              color: colors.tryOn,
                              weight: FontWeight.w800,
                            ).copyWith(fontSize: 13),
                          ),
                          TextSpan(
                            text: 'AI previews left',
                            style: AppTypography.caption(
                              color: colors.textPrimary,
                              weight: FontWeight.w600,
                            ).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressableScale(
                    onTap: _openModelPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.primary.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'All models',
                            style: AppTypography.caption(
                              color: colors.primary,
                              weight: FontWeight.w700,
                            ).copyWith(fontSize: 11),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Model Avatars Strip
          presetsAsync.maybeWhen(
            data: (presets) {
              if (presets.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  itemCount: presets.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == presets.length) {
                      return PressableScale(
                        onTap: _openPhotoGuidance,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.border, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '+ You',
                                style: AppTypography.caption(
                                  color: colors.textPrimary,
                                  weight: FontWeight.w600,
                                ).copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final model = presets[index];
                    final isSelected = session.selectedPhoto?.id == model.id;
                    final shortName = model.label.split(' ').first;

                    return PressableScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(tryOnNotifierProvider.notifier)
                            .selectPhoto(model);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary.withOpacity(0.1)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.border.withOpacity(0.6),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withOpacity(0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? colors.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CachedNetworkImage(
                                imageUrl: model.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.person, size: 14),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              shortName,
                              style: AppTypography.caption(
                                color: isSelected
                                    ? colors.primary
                                    : colors.textSecondary,
                                weight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ).copyWith(fontSize: 11),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 3),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: colors.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _buildMainStage(context, session),
            ),
          ),

          if (session.currentResult == null)
            _buildGarmentTray(context, session, catalogAsync),

          _buildBottomActionBar(context, session),
        ],
      ),
    );
  }

  Widget _buildMainStage(BuildContext context, TryOnSessionState session) {
    final colors = context.colors;
    final product = session.selectedProduct;

    // Never a dead end: unsupported pieces fall back to normal shopping.
    if (product != null && !product.isTryonEligible) {
      return _StageMessage(
        icon: Icons.checkroom_outlined,
        title: 'Not available for this piece',
        message: ClothsyCopy.tryOnUnsupported,
        primaryLabel: 'Back to the product',
        onPrimary: () => context.push('/product/${product.id}'),
        secondaryLabel: 'Try another piece',
        onSecondary: () =>
            ref.read(tryOnNotifierProvider.notifier).resetSession(),
      );
    }

    if (session.status == TryOnJobStatus.validatingPhoto) {
      return const _StageMessage(
        icon: Icons.cloud_upload_outlined,
        title: 'Saving your photo…',
        message: 'Only you can see it, and you can delete it anytime.',
        busy: true,
      );
    }

    if (session.isProcessing) {
      return TryOnShimmerLoading(
        currentStep: session.currentStep,
        onCancel: () => ref.read(tryOnNotifierProvider.notifier).cancel(),
      );
    }

    if (session.status == TryOnJobStatus.failed &&
        session.errorMessage != null) {
      return _StageMessage(
        icon: Icons.photo_camera_back_outlined,
        title: "Let's try that again",
        message: session.errorMessage!,
        primaryLabel: 'Try again',
        onPrimary: () => _generate(),
        secondaryLabel: 'Use another photo',
        onSecondary: _openModelPicker,
      );
    }

    final photo = session.selectedPhoto;
    final result = session.currentResult;
    if (result != null && photo != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          BeforeAfterSlider(
            beforeImageUrl: photo.imageUrl,
            beforeImage: TryOnPhotoImage(photo: photo),
            afterImageUrl: result.resultImageUrl,
            beforeLabel: photo.isPreset ? 'Model' : 'Your photo',
            afterLabel: ClothsyCopy.tryOnResultLabel,
          ),
          // Every result is labelled honestly (Blueprint section 35).
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deepInk.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ClothsyCopy.tryOnDisclaimer,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (photo != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TryOnPhotoImage(photo: photo),
              CustomPaint(
                painter: _FramingOverlayPainter(
                  borderColor: Colors.white.withOpacity(0.55),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.deepInk.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            photo.isPreset ? photo.label : 'Your photo',
                            style: AppTypography.caption(
                              color: Colors.white,
                              weight: FontWeight.w600,
                            ).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: PressableScale(
                  onTap: _openModelPicker,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cameraswitch_outlined,
                              color: colors.textPrimary,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Switch',
                              style: AppTypography.caption(
                                color: colors.textPrimary,
                                weight: FontWeight.w700,
                              ).copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.deepInk.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: colors.tryOn,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product != null
                                  ? 'Selected: ${product.title} • Tap "Try it on" below'
                                  : 'Pick a piece and colour below, then tap "Try it on".',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(
                                color: Colors.white,
                                weight: FontWeight.w500,
                              ).copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _StageMessage(
      icon: Icons.add_a_photo_outlined,
      title: 'Choose a photo',
      message: 'Use one of our models, or your own photo.',
      primaryLabel: 'Choose a photo',
      onPrimary: _openModelPicker,
    );
  }

  Widget _buildGarmentTray(
    BuildContext context,
    TryOnSessionState session,
    AsyncValue<List<Product>> catalogAsync,
  ) {
    final colors = context.colors;
    final product = session.selectedProduct;
    final variant = session.selectedVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border.withOpacity(0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          catalogAsync.maybeWhen(
            data: (products) {
              final eligible = products
                  .where((p) => p.isTryonEligible && p.variants.isNotEmpty)
                  .toList();
              final categories = [
                'All',
                ...{for (final p in eligible) p.category},
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with product details
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Pick a piece',
                          style: AppTypography.bodyMedium(
                            weight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${eligible.length}',
                            style: AppTypography.caption(
                              color: colors.textSecondary,
                              weight: FontWeight.w700,
                            ).copyWith(fontSize: 10),
                          ),
                        ),
                        const Spacer(),
                        if (product != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${product.brand.isNotEmpty ? "${product.brand} • " : ""}${product.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption(
                                  color: colors.primary,
                                  weight: FontWeight.w700,
                                ).copyWith(fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Category Filter Chips
                  if (categories.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SizedBox(
                        height: 28,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isCatSelected =
                                _selectedGarmentCategory == cat;
                            return PressableScale(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedGarmentCategory = cat);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCatSelected
                                      ? colors.primary
                                      : colors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  cat,
                                  style: AppTypography.caption(
                                    color: isCatSelected
                                        ? Colors.white
                                        : colors.textSecondary,
                                    weight: isCatSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ).copyWith(fontSize: 11),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Garment Portrait Cards List
                  SizedBox(
                    height: 88,
                    child: Builder(
                      builder: (context) {
                        final filtered = _selectedGarmentCategory == 'All'
                            ? eligible
                            : eligible
                                  .where(
                                    (p) =>
                                        p.category == _selectedGarmentCategory,
                                  )
                                  .toList();

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final isSelected = product?.id == item.id;
                            return PressableScale(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(tryOnNotifierProvider.notifier)
                                    .selectGarment(item);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 66,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.border.withOpacity(0.7),
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors.primary.withOpacity(
                                              0.24,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: item.primaryImage,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, _, _) =>
                                          ColoredBox(
                                            color: colors.surfaceMuted,
                                          ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: colors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                          horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.75),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                        child: Text(
                                          CurrencyFormatter.format(item.price),
                                          textAlign: TextAlign.center,
                                          style: AppTypography.caption(
                                            color: Colors.white,
                                            weight: FontWeight.w700,
                                          ).copyWith(fontSize: 9),
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
                  ),
                ],
              );
            },
            orElse: () => SizedBox(
              height: 80,
              child: catalogAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => Center(
                  child: Text(
                    "Couldn't load pieces. Pull down to retry.",
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                ),
                data: (_) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Confirm the colour being visualised (Blueprint fig. 27, step 4).
          if (product != null && variant != null && product.isTryonEligible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Colour: ',
                          style: AppTypography.caption(
                            color: colors.textSecondary,
                            weight: FontWeight.w500,
                          ).copyWith(fontSize: 11),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            variant.colorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(
                              color: colors.textPrimary,
                              weight: FontWeight.w700,
                            ).copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ColorSwatchSelector(
                        circleSize: 28,
                        swatches: [
                          for (final v in product.variants)
                            ColorSwatchItem(
                              id: v.id,
                              name: v.colorName,
                              color: Color(
                                int.tryParse(v.colorHex) ??
                                    colors.textPrimary.toARGB32(),
                              ),
                            ),
                        ],
                        selectedSwatchId: variant.id,
                        onSwatchSelected: (item) => ref
                            .read(tryOnNotifierProvider.notifier)
                            .selectVariant(
                              product.variants.firstWhere(
                                (v) => v.id == item.id,
                              ),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    TryOnSessionState session,
  ) {
    final colors = context.colors;
    final result = session.currentResult;
    final product = session.selectedProduct;
    final unsupported = product != null && !product.isTryonEligible;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border.withOpacity(0.6))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: result != null
          ? Row(
              children: [
                ClothsyIconButton(
                  tooltip: 'New preview',
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: colors.textPrimary,
                  ),
                  onPressed: () => _generate(regenerate: true),
                ),
                const SizedBox(width: 8),
                ClothsyIconButton(
                  tooltip: 'Save look',
                  icon: Icon(
                    result.rating != null
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 20,
                    color: result.rating != null
                        ? colors.primary
                        : colors.textPrimary,
                  ),
                  onPressed: () {
                    ref.read(tryOnNotifierProvider.notifier).saveLook();
                    ClothsySnackbar.show(
                      context,
                      message: 'Saved to your looks',
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text:
                        'Select size • ${CurrencyFormatter.format(session.selectedVariant?.price ?? product?.price ?? 0)}',
                    onPressed: () => _chooseSizeAndAdd(session),
                  ),
                ),
              ],
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow:
                    (session.canGenerate &&
                        !unsupported &&
                        !session.isProcessing)
                    ? [
                        BoxShadow(
                          color: colors.tryOn.withOpacity(0.38),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: PrimaryButton(
                text: ClothsyCopy.tryOnButton,
                backgroundColor: colors.tryOn,
                icon: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 18,
                ),
                isLoading: session.isProcessing,
                onPressed: session.canGenerate && !unsupported
                    ? () => _generate()
                    : null,
              ),
            ),
    );
  }
}

/// A centred message in the stage area with up to two actions.
class _StageMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  const _StageMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Icon(icon, size: 40, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.h3(color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body(color: colors.textSecondary),
              ),
              if (primaryLabel != null) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  text: primaryLabel!,
                  height: 44,
                  onPressed: onPrimary,
                ),
              ],
              if (secondaryLabel != null) ...[
                const SizedBox(height: 8),
                SecondaryButton(
                  text: secondaryLabel!,
                  height: 44,
                  onPressed: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Select size → Add to bag" straight from the preview (Blueprint: every
/// result leads back to buying in one tap).
class _SizeSheet extends StatefulWidget {
  final Product product;
  final ProductVariant shown;

  const _SizeSheet({required this.product, required this.shown});

  static Future<ProductVariant?> show(
    BuildContext context,
    Product product,
    ProductVariant shown,
  ) {
    return showModalBottomSheet<ProductVariant>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SizeSheet(product: product, shown: shown),
    );
  }

  @override
  State<_SizeSheet> createState() => _SizeSheetState();
}

class _SizeSheetState extends State<_SizeSheet> {
  late String? _size = widget.shown.isAvailable ? widget.shown.size : null;

  /// The variant to buy for [size]: the colour shown if it comes in that
  /// size, otherwise any variant of that size.
  ProductVariant? _variantFor(String size) {
    final inSize = widget.product.variants.where(
      (v) => v.size == size && v.isAvailable,
    );
    if (inSize.isEmpty) return null;
    return inSize.firstWhere(
      (v) => v.colorName == widget.shown.colorName,
      orElse: () => inSize.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sizes = widget.product.availableSizes;
    final selected = _size == null ? null : _variantFor(_size!);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select size',
            style: AppTypography.h3(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.product.title} • ${widget.shown.colorName}',
            style: AppTypography.caption(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizeSelector(
            sizes: sizes,
            selectedSize: _size,
            unavailableSizes: [
              for (final s in sizes)
                if (_variantFor(s) == null) s,
            ],
            onSizeSelected: (s) => setState(() => _size = s),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            text: selected == null
                ? 'Choose a size'
                : 'Add to bag • ${CurrencyFormatter.format(selected.price)}',
            onPressed: selected == null
                ? null
                : () => Navigator.pop(context, selected),
          ),
        ],
      ),
    );
  }
}

class _FramingOverlayPainter extends CustomPainter {
  final Color borderColor;

  _FramingOverlayPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const corner = 24.0;
    const pad = 16.0;
    final w = size.width;
    final h = size.height;

    // Corner brackets that frame the body.
    for (final (x, y, dx, dy) in [
      (pad, pad, 1.0, 1.0),
      (w - pad, pad, -1.0, 1.0),
      (pad, h - pad, 1.0, -1.0),
      (w - pad, h - pad, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * corner, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * corner), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FramingOverlayPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor;
}
