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
          // Credits and photo switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colors.surfaceMuted,
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: colors.tryOn),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${session.remainingCredits} AI previews left',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(
                      color: colors.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openModelPicker,
                  child: Row(
                    children: [
                      Text(
                        'Change photo',
                        style: AppTypography.caption(
                          color: colors.primary,
                          weight: FontWeight.w600,
                        ),
                      ),
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

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TryOnPhotoImage(photo: photo),
            CustomPaint(
              painter: _FramingOverlayPainter(
                borderColor: Colors.white.withOpacity(0.5),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _Pill(
                icon: Icons.person,
                label: photo.isPreset ? photo.label : 'Your photo',
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: PressableScale(
                onTap: _openModelPicker,
                child: _Pill(
                  icon: Icons.cameraswitch_outlined,
                  label: 'Switch',
                  light: true,
                ),
              ),
            ),
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
                  color: AppColors.deepInk.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colors.tryOn, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pick a piece and colour below, then tap "Try it on".',
                        style: AppTypography.caption(color: Colors.white),
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
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Pick a piece',
                  style: AppTypography.bodyMedium(
                    weight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (product != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 76,
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
              data: (products) {
                final eligible = products
                    .where((p) => p.isTryonEligible && p.variants.isNotEmpty)
                    .toList();
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: eligible.length,
                  itemBuilder: (context, index) {
                    final item = eligible[index];
                    final isSelected = product?.id == item.id;
                    return PressableScale(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(tryOnNotifierProvider.notifier)
                            .selectGarment(item);
                      },
                      child: Container(
                        width: 60,
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
                        child: CachedNetworkImage(
                          imageUrl: item.primaryImage,
                          fit: BoxFit.cover,
                          errorWidget: (context, _, _) =>
                              ColoredBox(color: colors.surfaceMuted),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Confirm the colour being visualised (Blueprint fig. 27, step 4).
          if (product != null && variant != null && product.isTryonEligible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Colour: ',
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                  Flexible(
                    child: Text(
                      variant.colorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                        color: colors.textPrimary,
                        weight: FontWeight.w700,
                      ),
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
        border: Border(top: BorderSide(color: colors.border)),
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
          : PrimaryButton(
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool light;

  const _Pill({required this.icon, required this.label, this.light = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = light ? colors.textPrimary : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: light
            ? colors.surface.withOpacity(0.9)
            : AppColors.deepInk.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption(color: fg, weight: FontWeight.w600),
          ),
        ],
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
