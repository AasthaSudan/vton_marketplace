import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';

class BeforeAfterSlider extends StatefulWidget {
  final String beforeImageUrl;
  final String afterImageUrl;

  /// Shown instead of [beforeImageUrl] when given (e.g. a photo that only
  /// exists on this device).
  final Widget? beforeImage;
  final double initialSplit;
  final String beforeLabel;
  final String afterLabel;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.beforeImage,
    this.initialSplit = 0.5,
    this.beforeLabel = 'Original',
    this.afterLabel = 'Clothsy AI Result',
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  late double _splitPercent;

  @override
  void initState() {
    super.initState();
    _splitPercent = widget.initialSplit.clamp(0.05, 0.95);
  }

  void _updateSplit(double localDx, double totalWidth) {
    if (totalWidth <= 0) return;
    setState(() {
      _splitPercent = (localDx / totalWidth).clamp(0.05, 0.95);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. After Image (Full background layer)
              CachedNetworkImage(
                imageUrl: widget.afterImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: colors.surfaceMuted,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: colors.surfaceMuted,
                  child: const Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),

              // 2. Before Image (Clipped by the split slider)
              ClipRect(
                clipper: _HorizontalSplitClipper(splitFactor: _splitPercent),
                child:
                    widget.beforeImage ??
                    CachedNetworkImage(
                      imageUrl: widget.beforeImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: colors.surfaceMuted),
                      errorWidget: (context, url, error) => Container(
                        color: colors.surfaceMuted,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                        ),
                      ),
                    ),
              ),

              // 3. Before Tag (Top Left)
              Positioned(
                top: 16,
                left: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _splitPercent > 0.15 ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.beforeLabel,
                      style: AppTypography.caption(
                        color: Colors.white,
                      ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

              // 4. After Tag (Top Right)
              Positioned(
                top: 16,
                right: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _splitPercent < 0.85 ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: context.colors.rating,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.afterLabel,
                          style: AppTypography.caption(
                            color: Colors.white,
                          ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Divider Line
              Positioned(
                left: width * _splitPercent - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),

              // 6. Circular slider handle
              Positioned(
                left: width * _splitPercent - 20,
                top: height / 2 - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.compare_arrows_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // 7. Gesture Detector Overlay
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    _updateSplit(details.localPosition.dx, width);
                  },
                  onTapDown: (details) {
                    _updateSplit(details.localPosition.dx, width);
                  },
                  onDoubleTap: () {
                    setState(() {
                      _splitPercent = 0.5;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double splitFactor;

  _HorizontalSplitClipper({required this.splitFactor});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * splitFactor, size.height);
  }

  @override
  bool shouldReclip(_HorizontalSplitClipper oldClipper) {
    return oldClipper.splitFactor != splitFactor;
  }
}
