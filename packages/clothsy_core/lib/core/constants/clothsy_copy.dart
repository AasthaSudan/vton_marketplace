/// Clothsy voice & key microcopy (Brand Blueprint v1.0, section 09).
///
/// Clothsy talks like a stylish, honest friend: helpful first, playful when it
/// fits, always clear when money, delivery or personal data is involved. Keep
/// user-facing strings for these moments here so every app says them the same
/// way.
class ClothsyCopy {
  ClothsyCopy._();

  // Brand
  static const String tagline = 'See it on you.';
  static const String promise =
      'Discover it. See it on you. Love what arrives.';

  // Clothsy AI Try-On
  static const String tryOnButton = 'Try it on';
  static const String tryOnConsent =
      'We use your photo only to create this preview. '
      'You can delete it anytime from Settings.';
  static const String tryOnDisclaimer =
      'AI preview — an estimate of the look, not a guarantee of fit.';
  static const String tryOnResultLabel = 'AI preview';
  static const String tryOnUnsupported =
      "Try-On isn't available for this piece yet — "
      'size help and reviews can still guide you.';

  // Bag
  static const String emptyBagTitle = "Your bag's feeling light";
  static const String emptyBagMessage = "Let's find something you'll love.";

  // Search
  static const String emptySearchTitle = 'No exact matches';
  static const String emptySearchMessage =
      "Here are styles close to what you're looking for.";

  // Orders & payments
  static const String orderPlacedTitle = 'Yay! Your order is confirmed.';
  static const String orderPlacedMessage =
      "We'll keep you posted at every step.";
  static const String paymentFailed =
      "Payment didn't go through. If any amount was debited, it will be "
      'refunded automatically. Try again or pick another method.';

  /// "You earned 45 Clothsy Coins on this order. Use them on your next find."
  static String coinsEarned(int coins) =>
      'You earned $coins Clothsy Coins on this order. '
      'Use them on your next find.';
}
