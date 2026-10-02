import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/features/profile/domain/entities/style_preferences.dart';
import 'package:clothsy_core/shared/widgets/badges/seller_badge.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/shared/widgets/inputs/clothsy_text_field.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import '../../profile/presentation/providers/profile_providers.dart';

/// Categories offered during onboarding (handles match the catalogue).
const _categories = <(String, String)>[
  ('women', 'Women'),
  ('men', 'Men'),
  ('dresses', 'Dresses'),
  ('tops', 'Tops'),
  ('outerwear', 'Outerwear'),
  ('ethnic', 'Ethnic wear'),
  ('shoes', 'Shoes'),
  ('bags', 'Bags'),
];

/// "Tell us your style" — the personalisation steps after sign-in
/// (Blueprint fig. 13): name, favourite categories, looks, brands and
/// budget. Every step can be skipped; the answers shape the first feed.
class StyleOnboardingScreen extends ConsumerStatefulWidget {
  /// Where to go when done, e.g. back to checkout.
  final String? redirectPath;

  const StyleOnboardingScreen({super.key, this.redirectPath});

  @override
  ConsumerState<StyleOnboardingScreen> createState() =>
      _StyleOnboardingScreenState();
}

class _StyleOnboardingScreenState extends ConsumerState<StyleOnboardingScreen> {
  static const _stepCount = 5;

  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _step = 0;
  bool _saving = false;
  StylePreferences _prefs = const StylePreferences();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null && !user.isGuest) _nameController.text = user.name;
    // Editing from Profile: start from what they chose before.
    ref.read(profileRepositoryProvider).getStylePreferences().then((saved) {
      if (saved != null && mounted) setState(() => _prefs = saved);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggle(List<String> list, String id, void Function(List<String>) set) {
    final next = [...list];
    next.contains(id) ? next.remove(id) : next.add(id);
    setState(() => set(next));
  }

  void _next() {
    if (_step == _stepCount - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final auth = ref.read(authProvider);
      if (name.isNotEmpty && auth.isAuthenticated && name != auth.user?.name) {
        await ref.read(authProvider.notifier).updateProfile(name: name);
      }
      await ref
          .read(profileRepositoryProvider)
          .saveStylePreferences(_prefs.copyWith(completedAt: DateTime.now()));
      ref.invalidate(stylePreferencesProvider);
    } catch (_) {
      // Preferences only personalise the feed: never block shopping on them.
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ClothsySnackbar.show(
      context,
      message: _prefs.isEmpty
          ? 'All set. Clothsy will learn your style as you browse.'
          : 'Your feed is ready.',
      type: SnackbarType.success,
    );
    final redirect = widget.redirectPath;
    context.go(redirect != null && redirect.isNotEmpty ? redirect : '/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _stepCount,
                        minHeight: 6,
                        backgroundColor: colors.surfaceMuted,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _finish,
                    child: Text(
                      'Skip',
                      style: AppTypography.bodyMedium(
                        color: colors.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepPage(
                    title: 'What should we call you?',
                    subtitle: 'So your orders and messages feel like yours.',
                    child: ClothsyTextField(
                      label: 'Your name',
                      hint: 'e.g. Riya',
                      controller: _nameController,
                    ),
                  ),
                  _StepPage(
                    title: 'What do you shop for?',
                    subtitle: 'Pick as many as you like.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (id, label) in _categories)
                          _ChoiceChip(
                            label: label,
                            selected: _prefs.categories.contains(id),
                            onTap: () => _toggle(
                              _prefs.categories,
                              id,
                              (v) => _prefs = _prefs.copyWith(categories: v),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StepPage(
                    title: 'Pick looks you like',
                    subtitle: 'We use these to style your first feed.',
                    child: _LookGrid(
                      selected: _prefs.looks,
                      onToggle: (id) => _toggle(
                        _prefs.looks,
                        id,
                        (v) => _prefs = _prefs.copyWith(looks: v),
                      ),
                    ),
                  ),
                  _StepPage(
                    title: 'Brands you love',
                    subtitle: "We'll show you their new drops first.",
                    child: _BrandPicker(
                      selected: _prefs.brandIds,
                      onToggle: (id) => _toggle(
                        _prefs.brandIds,
                        id,
                        (v) => _prefs = _prefs.copyWith(brandIds: v),
                      ),
                    ),
                  ),
                  _StepPage(
                    title: 'Your usual budget',
                    subtitle: 'Per piece. Optional — you can change it later.',
                    child: Column(
                      children: [
                        for (final range in BudgetRange.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChoiceTile(
                              label: range.label,
                              selected: _prefs.budget == range,
                              onTap: () => setState(() {
                                _prefs = _prefs.budget == range
                                    ? _prefs.copyWith(clearBudget: true)
                                    : _prefs.copyWith(budget: range);
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PrimaryButton(
                text: _step == _stepCount - 1 ? 'Show my feed' : 'Continue',
                isLoading: _saving,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h1(color: colors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTypography.body(color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.bodyMedium(
              color: selected ? colors.onPrimary : colors.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? colors.surfaceMuted : colors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium(
                    color: colors.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.border,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LookGrid extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _LookGrid({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 3 / 4,
      children: [
        for (final look in StyleLook.all)
          Semantics(
            button: true,
            selected: selected.contains(look.id),
            label: look.label,
            child: GestureDetector(
              onTap: () => onToggle(look.id),
              child: ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: look.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, _) =>
                          ColoredBox(color: colors.surfaceMuted),
                      errorWidget: (context, _, _) =>
                          ColoredBox(color: colors.surfaceMuted),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.deepInk.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Text(
                        look.label,
                        style: AppTypography.bodyMedium(
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected.contains(look.id))
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.cardRadius,
                          border: Border.all(color: colors.primary, width: 3),
                        ),
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: colors.primary,
                          size: 26,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BrandPicker extends ConsumerWidget {
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _BrandPicker({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sellers = ref.watch(sellersProvider);
    return sellers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Text(
        "We couldn't load brands right now — you can skip this step.",
        style: AppTypography.body(color: colors.textSecondary),
      ),
      data: (list) => Column(
        children: [
          for (final seller in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onToggle(seller.id),
                borderRadius: AppRadius.cardRadius,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected.contains(seller.id)
                        ? colors.surfaceMuted
                        : colors.surface,
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(
                      color: selected.contains(seller.id)
                          ? colors.primary
                          : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      SellerAvatar(seller: seller, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    seller.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium(
                                      color: colors.textPrimary,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (seller.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const VerifiedBadge(size: 14),
                                ],
                              ],
                            ),
                            Text(
                              seller.tagline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected.contains(seller.id)
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: selected.contains(seller.id)
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
