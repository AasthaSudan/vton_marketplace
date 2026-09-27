import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/buttons/pressable_scale.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _slides = [
    {
      'kicker': 'DISCOVER',
      'headline': 'Your\nStyle,\nYour\nStory',
      'subtitle': 'Handpicked fashion\nfor every moment.',
      'card1Image':
          'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=900&auto=format&fit=crop&q=80',
      'card2Image':
          'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=900&auto=format&fit=crop&q=80',
    },
    {
      'kicker': 'AI TRY-ON',
      'headline': 'Try\nEvery\nOutfit\nLive',
      'subtitle': 'Photorealistic precision\nbefore you buy.',
      'card1Image':
          'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=900&auto=format&fit=crop&q=80',
      'card2Image':
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=900&auto=format&fit=crop&q=80',
    },
    {
      'kicker': 'ATELIER',
      'headline': 'Pure\nLuxury,\nModern\nChic',
      'subtitle': 'Crafted silks, linens\nand contemporary cuts.',
      'card1Image':
          'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=900&auto=format&fit=crop&q=80',
      'card2Image':
          'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?w=900&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (mounted) context.go('/');
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _fadeController.reset();
      _pageController
          .nextPage(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOut,
          )
          .then((_) => _fadeController.forward());
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sh = constraints.maxHeight;
            final sw = constraints.maxWidth;
            final isCompact = sh < 680;
            final isTiny = sh < 580;

            return Column(
              children: [
                // ── Top Bar ──────────────────────────────────────────────
                _TopBar(onSkip: _completeOnboarding, isTiny: isTiny),

                // ── Slides ───────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) {
                      _fadeController.reset();
                      setState(() => _currentPage = i);
                      _fadeController.forward();
                    },
                    itemBuilder: (context, index) {
                      return FadeTransition(
                        opacity: _fadeAnim,
                        child: _SlideContent(
                          slide: _slides[index],
                          isCompact: isCompact,
                          isTiny: isTiny,
                          sw: sw,
                          sh: sh,
                        ),
                      );
                    },
                  ),
                ),

                // ── Bottom Bar ───────────────────────────────────────────
                _BottomBar(
                  slideCount: _slides.length,
                  currentPage: _currentPage,
                  onNext: _onNext,
                  onDot: (i) => _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  isTiny: isTiny,
                  colors: colors,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Top Bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip, required this.isTiny});
  final VoidCallback onSkip;
  final bool isTiny;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isTiny ? 4 : 8, 20, isTiny ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand mark
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.bolt_rounded,
                    size: 14, color: colors.onPrimary),
              ),
              const SizedBox(width: 7),
              Text(
                'Clothsy',
                style: AppTypography.label(
                  color: const Color(0xFF1E142B),
                  weight: FontWeight.w700,
                ).copyWith(fontSize: 15, letterSpacing: 0.2),
              ),
            ],
          ),
          // Skip
          PressableScale(
            onTap: onSkip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                'Skip',
                style: AppTypography.caption(
                  color: const Color(0xFF9A91A4),
                  weight: FontWeight.w600,
                ).copyWith(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide Content ────────────────────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  const _SlideContent({
    required this.slide,
    required this.isCompact,
    required this.isTiny,
    required this.sw,
    required this.sh,
  });

  final Map<String, dynamic> slide;
  final bool isCompact;
  final bool isTiny;
  final double sw;
  final double sh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, box) {
          final aw = box.maxWidth;
          final ah = box.maxHeight;

          // Right collage: 50% of width, text column: ~46%, 4% gap
          final rightW = (aw * 0.50).clamp(130.0, 220.0);
          final leftW = aw - rightW - 8.0;

          // Collage is a fixed tight height — cards close, small natural tuck
          final card1H = (ah * 0.46).clamp(130.0, 245.0);
          final card2H = (ah * 0.42).clamp(115.0, 220.0);
          final card1W = (rightW * 0.90).clamp(110.0, 200.0);
          final card2W = (rightW * 0.86).clamp(105.0, 195.0);
          // Card 2 tucks just 12px under Card 1 — close but not buried
          final tuck = 12.0;
          final card2Top = card1H - tuck;
          final collageH = card2Top + card2H + 4;

          // Font sizes
          final kickerSize = isTiny ? 9.5 : isCompact ? 10.5 : 11.5;
          final titleSize = isTiny ? 28.0 : isCompact ? 34.0 : 40.0;
          final subtitleSize = isTiny ? 11.5 : isCompact ? 12.5 : 13.5;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left: Typography ─────────────────────────────────────
              SizedBox(
                width: leftW,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kicker pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EBF8),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        slide['kicker'] as String,
                        style: AppTypography.label(
                          color: const Color(0xFF6B4FA0),
                          weight: FontWeight.w700,
                        ).copyWith(
                          fontSize: kickerSize,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    SizedBox(height: isTiny ? 10 : 16),

                    // Headline — each word on its own line, FittedBox prevents overflow
                    ...(slide['headline'] as String)
                        .split('\n')
                        .map((word) => _HeadlineWord(
                              word: word,
                              fontSize: titleSize,
                              color: word.endsWith(',')
                                  ? const Color(0xFF5B4574)
                                  : const Color(0xFF110E1B),
                            )),

                    SizedBox(height: isTiny ? 10 : 16),

                    // Divider accent
                    Container(
                      width: 28,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: isTiny ? 8 : 12),

                    // Subtitle
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        slide['subtitle'] as String,
                        style: AppTypography.body(
                          color: const Color(0xFF7E7889),
                        ).copyWith(
                          fontSize: subtitleSize,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Right: Staggered Image Collage (tight, overlapping) ───
              Center(
                child: SizedBox(
                  width: rightW,
                  height: collageH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Decorative pill columns (right edge, behind card 1)
                      Positioned(
                        top: 12,
                        right: 0,
                        height: card1H * 0.65,
                        width: 20,
                        child: _PillColumns(),
                      ),

                      // Card 1 – Top, arched, right-aligned
                      Positioned(
                        top: 0,
                        right: 0,
                        width: card1W,
                        height: card1H,
                        child: _ImageCard(
                          imageUrl: slide['card1Image'] as String,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(card1W / 2),
                            topRight: Radius.circular(card1W / 2),
                            bottomLeft: const Radius.circular(20),
                            bottomRight: const Radius.circular(20),
                          ),
                        ),
                      ),

                      // Card 2 – Overlapping Card 1, left-offset, rounded
                      Positioned(
                        top: card2Top,
                        left: 0,
                        width: card2W,
                        height: card2H,
                        child: _ImageCard(
                          imageUrl: slide['card2Image'] as String,
                          borderRadius: BorderRadius.circular(20),
                          hasBorder: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Headline Word ────────────────────────────────────────────────────────────

class _HeadlineWord extends StatelessWidget {
  const _HeadlineWord({
    required this.word,
    required this.fontSize,
    required this.color,
  });
  final String word;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        word,
        maxLines: 1,
        softWrap: false,
        style: AppTypography.display(color: color).copyWith(
          fontSize: fontSize,
          height: 1.08,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Image Card ───────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.imageUrl,
    required this.borderRadius,
    this.hasBorder = false,
  });
  final String imageUrl;
  final BorderRadius borderRadius;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB49DCF),
        borderRadius: borderRadius,
        border: hasBorder ? Border.all(color: Colors.white, width: 3.5) : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E142B).withOpacity(hasBorder ? 0.22 : 0.14),
            blurRadius: hasBorder ? 20 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(color: const Color(0xFFD4C4E8)),
        errorWidget: (context, url, err) => Container(
          color: const Color(0xFFD4C4E8),
          child: const Icon(Icons.image_outlined,
              color: Colors.white60, size: 28),
        ),
      ),
    );
  }
}

// ─── Pill Columns (Decorative) ────────────────────────────────────────────────

class _PillColumns extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        3,
        (i) => Container(
          width: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFC7B6DC).withOpacity(0.8),
                const Color(0xFFC7B6DC).withOpacity(0.0),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.slideCount,
    required this.currentPage,
    required this.onNext,
    required this.onDot,
    required this.isTiny,
    required this.colors,
  });

  final int slideCount;
  final int currentPage;
  final VoidCallback onNext;
  final ValueChanged<int> onDot;
  final bool isTiny;
  final ClothsyColorExtension colors;

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == slideCount - 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        isTiny ? 8 : 12,
        20,
        isTiny ? 16 : 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots
          Row(
            children: List.generate(slideCount, (i) {
              final active = i == currentPage;
              return GestureDetector(
                onTap: () => onDot(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.only(right: 7),
                  height: 6,
                  width: active ? 22 : 6,
                  decoration: BoxDecoration(
                    color: active
                        ? colors.primary
                        : const Color(0xFFD8D2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),

          // CTA button
          PressableScale(
            onTap: onNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: EdgeInsets.symmetric(
                horizontal: isTiny ? 18 : 22,
                vertical: isTiny ? 11 : 13,
              ),
              decoration: BoxDecoration(
                color: isLast ? colors.primary : const Color(0xFF1E142B),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast ? 'Get Started' : 'Next',
                    style: AppTypography.button(
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ).copyWith(fontSize: isTiny ? 13 : 14),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
