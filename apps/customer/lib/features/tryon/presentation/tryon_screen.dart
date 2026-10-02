import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_photo.dart';
import 'package:clothsy_core/features/tryon/domain/entities/tryon_session.dart';
import 'providers/tryon_provider.dart';
import 'tryon_history_screen.dart';
import 'widgets/before_after_slider.dart';
import 'widgets/model_photo_picker_sheet.dart';
import 'widgets/photo_guidance_sheet.dart';
import 'widgets/tryon_shimmer_loading.dart';

class TryonScreen extends ConsumerStatefulWidget {
  final String? initialProductId;

  const TryonScreen({super.key, this.initialProductId});

  @override
  ConsumerState<TryonScreen> createState() => _TryonScreenState();
}

class _TryonScreenState extends ConsumerState<TryonScreen> {
  bool _initializedProduct = false;

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

    final repo = ref.read(catalogRepositoryProvider);
    if (widget.initialProductId != null) {
      final p = await repo.getProductById(widget.initialProductId!);
      if (p != null && mounted) {
        ref
            .read(tryOnNotifierProvider.notifier)
            .selectGarment(
              p,
              p.variants.isNotEmpty ? p.variants.first : _dummyVariant(p),
            );
        return;
      }
    }

    // Default to first catalog item if none provided
    final all = await repo.getProducts();
    if (all.isNotEmpty && mounted) {
      final p = all.first;
      ref
          .read(tryOnNotifierProvider.notifier)
          .selectGarment(
            p,
            p.variants.isNotEmpty ? p.variants.first : _dummyVariant(p),
          );
    }
  }

  ProductVariant _dummyVariant(Product p) {
    return ProductVariant(
      id: 'default_${p.id}',
      title: 'Standard Fit',
      size: p.availableSizes.isNotEmpty ? p.availableSizes.first : 'M',
      colorName: 'Classic',
      colorHex: '#2B1E3F',
      price: p.price,
    );
  }

  void _openPhotoGuidance() {
    PhotoGuidanceSheet.show(
      context,
      onConsentGranted: () {
        ref.read(tryOnNotifierProvider.notifier).grantConsent();
      },
      onCameraSelected: () {
        final customPhoto = TryOnPhoto(
          id: 'camera_capture_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Live Studio Camera',
          imageUrl:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
          isPreset: false,
          createdAt: DateTime.now(),
        );
        ref.read(tryOnNotifierProvider.notifier).selectPhoto(customPhoto);
        ClothsySnackbar.show(
          context,
          message: 'Photo captured & ready to style',
        );
      },
      onGallerySelected: () {
        final customPhoto = TryOnPhoto(
          id: 'gallery_upload_${DateTime.now().millisecondsSinceEpoch}',
          label: 'My Uploaded Photo',
          imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
          isPreset: false,
          createdAt: DateTime.now(),
        );
        ref.read(tryOnNotifierProvider.notifier).selectPhoto(customPhoto);
        ClothsySnackbar.show(context, message: 'Photo selected from gallery');
      },
      onPresetSelected: () {
        _openModelPicker();
      },
    );
  }

  void _openModelPicker() {
    ModelPhotoPickerSheet.show(context, (photo) {
      ref.read(tryOnNotifierProvider.notifier).selectPhoto(photo);
      ClothsySnackbar.show(
        context,
        message: 'Active photo updated: ${photo.label}',
      );
    });
  }

  Future<void> _handleStartTryOn() async {
    final session = ref.read(tryOnNotifierProvider);

    if (!session.hasConsented) {
      _openPhotoGuidance();
      return;
    }

    HapticFeedback.mediumImpact();
    final result = await ref
        .read(tryOnNotifierProvider.notifier)
        .generateTryOn();
    if (result != null && mounted) {
      HapticFeedback.lightImpact();
      ClothsySnackbar.show(
        context,
        message: 'Clothsy AI look generated successfully!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = ref.watch(tryOnNotifierProvider);
    final history = ref.watch(tryOnHistoryProvider);
    final catalogAsync = ref.watch(productsProvider);

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
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: colors.primary,
                  size: 16,
                ),
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
          // History action with counter badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.history_outlined, size: 22),
                tooltip: 'Look History',
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: 'Styling Guide & Privacy',
            onPressed: _openPhotoGuidance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top credit banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colors.surfaceMuted,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 16,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Clothsy Atelier Tier • Unlimited Try-Ons',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                            color: colors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openModelPicker,
                  child: Row(
                    children: [
                      Text(
                        'Change Model',
                        style: AppTypography.caption(
                          color: colors.primary,
                        ).copyWith(fontWeight: FontWeight.w600),
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
              ],
            ),
          ),

          // Main Viewport
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildMainStage(context, session),
            ),
          ),

          // Horizontal Garment Tray
          _buildGarmentTray(context, session, catalogAsync),

          // Bottom Action Bar
          _buildBottomActionBar(context, session),
        ],
      ),
    );
  }

  Widget _buildMainStage(BuildContext context, TryOnSessionState session) {
    final colors = context.colors;

    // 1. Processing Shimmer State
    if (session.isProcessing) {
      return TryOnShimmerLoading(
        currentStep: session.currentStep,
        onCancel: () {
          ref.read(tryOnNotifierProvider.notifier).resetSession();
        },
      );
    }

    // 2. Completed State: Before / After Slider
    if (session.currentResult != null && session.selectedPhoto != null) {
      final res = session.currentResult!;
      return Stack(
        fit: StackFit.expand,
        children: [
          BeforeAfterSlider(
            beforeImageUrl: session.selectedPhoto!.imageUrl,
            afterImageUrl: res.resultImageUrl,
            beforeLabel: 'Your photo',
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
                  color: Colors.black.withOpacity(0.55),
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

    // 3. Ready State: Model Photo with Framing Overlay
    final photo = session.selectedPhoto;
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: photo.imageUrl, fit: BoxFit.cover),
            // Framing silhouette guide overlay
            CustomPaint(
              painter: _FramingOverlayPainter(
                borderColor: Colors.white.withOpacity(0.5),
                guideColor: colors.accent.withOpacity(0.3),
              ),
            ),
            // Top Model Tag
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      photo.label,
                      style: AppTypography.caption(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            // Floating "Switch Model" Button
            Positioned(
              top: 16,
              right: 16,
              child: PressableScale(
                onTap: _openModelPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cameraswitch_outlined,
                        size: 14,
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Switch',
                        style: AppTypography.caption(
                          color: colors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom "Tap to Style" Hint
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colors.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select a garment below and tap "Generate Try-On"',
                        style: AppTypography.caption(
                          color: Colors.white,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. No photo selected yet
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 48,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No Model Photo Selected',
                  style: AppTypography.h3(color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a studio preset or take a photo',
                  style: AppTypography.caption(color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  onPressed: _openPhotoGuidance,
                  child: const Text(
                    'Select Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGarmentTray(
    BuildContext context,
    TryOnSessionState session,
    AsyncValue<List<Product>> catalogAsync,
  ) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Atelier Garments',
                  style: AppTypography.bodyMedium(
                    weight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (session.selectedProduct != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        '${session.selectedProduct!.title} • ${session.selectedVariant?.size ?? 'M'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ).copyWith(fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 86,
            child: catalogAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error: $err',
                  style: AppTypography.caption(color: colors.error),
                ),
              ),
              data: (products) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected =
                        session.selectedProduct?.id == product.id;

                    return PressableScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final variant = product.variants.isNotEmpty
                            ? product.variants.first
                            : _dummyVariant(product);
                        ref
                            .read(tryOnNotifierProvider.notifier)
                            .selectGarment(product, variant);
                      },
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                              imageUrl: product.primaryImage,
                              fit: BoxFit.cover,
                            ),
                            if (isSelected)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 10,
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
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    TryOnSessionState session,
  ) {
    final colors = context.colors;
    final isResultReady = session.currentResult != null;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: isResultReady
          ? Row(
              children: [
                // Share Action
                ClothsyIconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  onPressed: () {
                    ClothsySnackbar.show(
                      context,
                      message: 'Look link copied! Ready to share with friends.',
                    );
                  },
                ),
                const SizedBox(width: 8),
                ClothsyIconButton(
                  icon: Icon(
                    session.currentResult?.rating != null
                        ? Icons.star
                        : Icons.star_border,
                    size: 20,
                    color: session.currentResult?.rating != null
                        ? Colors.amber
                        : colors.textPrimary,
                  ),
                  onPressed: () {
                    ref.read(tryOnNotifierProvider.notifier).rateResult(5);
                    ClothsySnackbar.show(
                      context,
                      message: 'Saved to your 5-star looks!',
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Direct Add to Cart Button
                Expanded(
                  child: PrimaryButton(
                    text:
                        'Add to Bag • ${CurrencyFormatter.format(session.selectedVariant?.price ?? session.selectedProduct?.price ?? 0)}',
                    icon: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () {
                      if (session.selectedProduct != null &&
                          session.selectedVariant != null) {
                        ref
                            .read(cartProvider.notifier)
                            .addToCart(
                              session.selectedProduct!,
                              session.selectedVariant!,
                            );
                        HapticFeedback.lightImpact();
                        ClothsySnackbar.show(
                          context,
                          message:
                              'Added ${session.selectedProduct!.title} to bag',
                        );
                        context.push('/cart');
                      }
                    },
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Generate Try-On',
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                    isLoading: session.isProcessing,
                    onPressed: session.canGenerate ? _handleStartTryOn : null,
                  ),
                ),
              ],
            ),
    );
  }
}

class _FramingOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color guideColor;

  _FramingOverlayPainter({required this.borderColor, required this.guideColor});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Corner crosshairs
    const cornerSize = 24.0;
    const padding = 16.0;

    // Top-Left
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding + cornerSize, padding),
      borderPaint,
    );
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding, padding + cornerSize),
      borderPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding - cornerSize, padding),
      borderPaint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + cornerSize),
      borderPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + cornerSize, size.height - padding),
      borderPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding, size.height - padding - cornerSize),
      borderPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding - cornerSize, size.height - padding),
      borderPaint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding, size.height - padding + cornerSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
