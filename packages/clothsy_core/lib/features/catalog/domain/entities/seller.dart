/// A brand / seller on the marketplace (Brand Blueprint, sections 25 & 37).
///
/// In Clothsy a "seller" and a "brand storefront" are the same thing: every
/// product belongs to exactly one seller, every order is split into one seller
/// order per seller, and each seller ships on its own.
class Seller {
  final String id;

  /// URL-friendly unique name, e.g. `noor-atelier`.
  final String handle;
  final String name;
  final String tagline;
  final String story;
  final String? logoUrl;
  final String? bannerUrl;
  final String city;

  /// Passed Clothsy's KYC / verification review (shows the verified badge).
  final bool isVerified;

  /// Small or independent label (vs. an established brand).
  final bool isIndependent;
  final int followerCount;
  final double rating;

  /// Working days the seller needs to pack and hand over an order.
  final int dispatchDays;

  /// Days after delivery within which an item can be returned.
  final int returnWindowDays;

  const Seller({
    required this.id,
    required this.handle,
    required this.name,
    this.tagline = '',
    this.story = '',
    this.logoUrl,
    this.bannerUrl,
    this.city = '',
    this.isVerified = false,
    this.isIndependent = true,
    this.followerCount = 0,
    this.rating = 0,
    this.dispatchDays = 2,
    this.returnWindowDays = 7,
  });

  /// One or two capital letters for the avatar when there is no logo.
  String get monogram {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(p[0]))
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// "1.2K", "48.5K", "2.1M" — compact follower count for storefront headers.
  String get followersLabel {
    if (followerCount >= 1000000) {
      return '${(followerCount / 1000000).toStringAsFixed(1)}M';
    }
    if (followerCount >= 1000) {
      return '${(followerCount / 1000).toStringAsFixed(1)}K';
    }
    return '$followerCount';
  }
}
