/// What a shopper told Clothsy about their taste during onboarding
/// (Blueprint section 24, fig. 13). Every part is optional: skipping a step
/// leaves it empty, and Clothsy keeps learning from browsing instead.
class StylePreferences {
  /// Category handles they shop for, e.g. `women`, `dresses`.
  final List<String> categories;

  /// Look ids they liked, e.g. `minimal`, `streetwear` (see [StyleLook]).
  final List<String> looks;

  /// Seller ids of brands they love.
  final List<String> brandIds;

  /// Their usual spend per piece, if they shared it.
  final BudgetRange? budget;

  /// When onboarding was finished or skipped; null means never shown.
  final DateTime? completedAt;

  const StylePreferences({
    this.categories = const [],
    this.looks = const [],
    this.brandIds = const [],
    this.budget,
    this.completedAt,
  });

  bool get isEmpty =>
      categories.isEmpty && looks.isEmpty && brandIds.isEmpty && budget == null;

  StylePreferences copyWith({
    List<String>? categories,
    List<String>? looks,
    List<String>? brandIds,
    BudgetRange? budget,
    bool clearBudget = false,
    DateTime? completedAt,
  }) {
    return StylePreferences(
      categories: categories ?? this.categories,
      looks: looks ?? this.looks,
      brandIds: brandIds ?? this.brandIds,
      budget: clearBudget ? null : (budget ?? this.budget),
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// The shape stored in `profiles.style_prefs` (and in local storage).
  Map<String, dynamic> toJson() => {
    'categories': categories,
    'looks': looks,
    'brand_ids': brandIds,
    'budget': budget?.id,
    'completed_at': completedAt?.toUtc().toIso8601String(),
  };

  factory StylePreferences.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toList() : const [];
    final completed = json['completed_at'];
    return StylePreferences(
      categories: strings(json['categories']),
      looks: strings(json['looks']),
      brandIds: strings(json['brand_ids']),
      budget: BudgetRange.fromId(json['budget'] as String?),
      completedAt: completed is String ? DateTime.tryParse(completed) : null,
    );
  }
}

/// Budget bands shown during onboarding, bounds in paise.
enum BudgetRange {
  under1000('under_1000', 'Under ₹1,000', 0, 100000),
  upTo2500('1000_2500', '₹1,000 – ₹2,500', 100000, 250000),
  upTo5000('2500_5000', '₹2,500 – ₹5,000', 250000, 500000),
  above5000('5000_plus', '₹5,000 and up', 500000, null);

  final String id;
  final String label;
  final int minPaise;
  final int? maxPaise;

  const BudgetRange(this.id, this.label, this.minPaise, this.maxPaise);

  static BudgetRange? fromId(String? id) {
    for (final range in values) {
      if (range.id == id) return range;
    }
    return null;
  }
}

/// A look a shopper can pick during onboarding.
class StyleLook {
  final String id;
  final String label;
  final String imageUrl;

  const StyleLook(this.id, this.label, this.imageUrl);

  static const all = [
    StyleLook(
      'minimal',
      'Minimal',
      'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=600&auto=format&fit=crop&q=80',
    ),
    StyleLook(
      'streetwear',
      'Streetwear',
      'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=600&auto=format&fit=crop&q=80',
    ),
    StyleLook(
      'ethnic_fusion',
      'Ethnic & fusion',
      'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=600&auto=format&fit=crop&q=80',
    ),
    StyleLook(
      'occasion',
      'Occasion',
      'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=600&auto=format&fit=crop&q=80',
    ),
    StyleLook(
      'workwear',
      'Workwear',
      'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=600&auto=format&fit=crop&q=80',
    ),
    StyleLook(
      'relaxed',
      'Relaxed',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=600&auto=format&fit=crop&q=80',
    ),
  ];
}
