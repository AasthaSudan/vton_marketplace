class PromoBannerItem {
  final String id;
  final String headline;
  final String subtitle;
  final String ctaText;
  final String imageUrl;
  final String? deepLinkTarget;

  const PromoBannerItem({
    required this.id,
    required this.headline,
    required this.subtitle,
    this.ctaText = 'Shop Now',
    required this.imageUrl,
    this.deepLinkTarget,
  });
}
