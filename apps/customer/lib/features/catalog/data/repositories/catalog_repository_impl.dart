import 'package:flutter/material.dart';
import 'package:clothsy_core/features/catalog/domain/entities/banner.dart';
import 'package:clothsy_core/features/catalog/domain/entities/collection.dart';
import 'package:clothsy_core/features/catalog/domain/entities/product.dart';
import 'package:clothsy_core/features/catalog/domain/repositories/catalog_repository.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  // Rich catalog dataset reflecting the Clothsy luxury fashion collection
  final List<Product> _products = [
    Product(
      id: 'p_lavender_blazer',
      handle: 'lavender-blazer',
      title: 'Lavender Blazer',
      brand: 'Clothsy Atelier',
      description:
          'Tailored to perfection, this blazer adds a touch of elegance to any outfit. Crafted from premium breathable stretch twill with structured notch lapels, flap pockets, and a graceful tailored silhouette. Perfect for both casual and formal occasions.',
      price: 799900,
      originalPrice: 999900,
      category: 'Women',
      rating: 4.8,
      reviewCount: 120,
      isFeatured: true,
      isNew: true,
      isTryonEligible: true,
      tags: ['Blazer', 'Outerwear', 'Women', 'Lavender', 'Featured'],
      availableSizes: ['S', 'M', 'L', 'XL'],
      images: [
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v_blazer_lavender',
          title: 'Soft Lavender / M',
          size: 'M',
          colorName: 'Soft Lavender',
          colorHex: '0xFFB9A6E0',
          price: 799900,
          originalPrice: 999900,
          imageUrl:
              'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=900&auto=format&fit=crop&q=80',
        ),
        ProductVariant(
          id: 'v_blazer_champagne',
          title: 'Warm Sand / S',
          size: 'S',
          colorName: 'Warm Sand',
          colorHex: '0xFFE7DCC7',
          price: 799900,
          originalPrice: 999900,
        ),
        ProductVariant(
          id: 'v_blazer_charcoal',
          title: 'Charcoal / L',
          size: 'L',
          colorName: 'Charcoal',
          colorHex: '0xFF363636',
          price: 799900,
          originalPrice: 999900,
        ),
        ProductVariant(
          id: 'v_blazer_black',
          title: 'Midnight Black / XL',
          size: 'XL',
          colorName: 'Midnight Black',
          colorHex: '0xFF1A1A1A',
          price: 799900,
          originalPrice: 999900,
        ),
      ],
    ),
    Product(
      id: 'p_minimal_overshirt',
      handle: 'minimal-overshirt',
      title: 'Minimal Overshirt',
      brand: 'Clothsy Studio',
      description:
          'Clean-cut contemporary overshirt made with premium structured cotton twill. Features natural horn buttons, tailored collar, and clean dual utility chest pockets.',
      price: 499900,
      originalPrice: 599900,
      category: 'Men',
      rating: 4.9,
      reviewCount: 88,
      isFeatured: true,
      isNew: true,
      isTryonEligible: true,
      tags: ['Shirt', 'Overshirt', 'Men', 'Featured'],
      availableSizes: ['S', 'M', 'L', 'XL'],
      images: [
        'https://images.unsplash.com/photo-1617137984095-74e4e5e3613f?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v_overshirt_sand',
          title: 'Khaki Sand / M',
          size: 'M',
          colorName: 'Khaki Sand',
          colorHex: '0xFFD2C4AE',
          price: 499900,
        ),
        ProductVariant(
          id: 'v_overshirt_charcoal',
          title: 'Deep Charcoal / L',
          size: 'L',
          colorName: 'Deep Charcoal',
          colorHex: '0xFF2E2E2E',
          price: 499900,
        ),
      ],
    ),
    Product(
      id: 'p_lavender_hoodie',
      handle: 'lavender-hoodie',
      title: 'Lavender Hoodie',
      brand: 'Clothsy Edit',
      description:
          'Ultra-soft heavyweight brushed organic cotton fleece hoodie with relaxed dropped shoulders, double-layered hood, and ribbed trims.',
      price: 399900,
      originalPrice: 499900,
      category: 'Women',
      rating: 4.7,
      reviewCount: 145,
      isFeatured: true,
      isNew: true,
      isTryonEligible: true,
      tags: ['Hoodie', 'Sweater', 'Women', 'Lavender', 'Featured'],
      availableSizes: ['XS', 'S', 'M', 'L', 'XL'],
      images: [
        'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v_hoodie_lavender',
          title: 'Pastel Lilac / M',
          size: 'M',
          colorName: 'Pastel Lilac',
          colorHex: '0xFFB9A6E0',
          price: 399900,
          originalPrice: 499900,
        ),
        ProductVariant(
          id: 'v_hoodie_white',
          title: 'Cloud White / S',
          size: 'S',
          colorName: 'Cloud White',
          colorHex: '0xFFF5F5F7',
          price: 399900,
          originalPrice: 499900,
        ),
      ],
    ),
    Product(
      id: 'p1',
      handle: 'silk-satin-maxi-dress',
      title: 'Silk Satin Maxi Dress',
      brand: 'Clothsy Atelier',
      description:
          'Cut on the bias for an effortless, figure-skimming drape. Crafted from premium 22-momme Mulberry silk satin with adjustable delicate straps and a subtle cowl neckline. Perfect for evenings and celebrations.',
      price: 499900,
      originalPrice: 799900,
      category: 'Dresses',
      rating: 4.9,
      reviewCount: 184,
      isFeatured: true,
      isNew: true,
      isTryonEligible: true,
      tags: ['Silk', 'Evening', 'Maxi', 'Dresses'],
      availableSizes: ['XS', 'S', 'M', 'L'],
      images: [
        'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v1_plum',
          title: 'Plum Noir / M',
          size: 'M',
          colorName: 'Plum Noir',
          colorHex: '0xFF2B1E3F',
          price: 499900,
          originalPrice: 799900,
          imageUrl:
              'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=900&auto=format&fit=crop&q=80',
        ),
        ProductVariant(
          id: 'v1_lilac',
          title: 'Soft Lilac / S',
          size: 'S',
          colorName: 'Soft Lilac',
          colorHex: '0xFFB9A6E0',
          price: 499900,
          originalPrice: 799900,
          imageUrl:
              'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?w=900&auto=format&fit=crop&q=80',
        ),
        ProductVariant(
          id: 'v1_cream',
          title: 'Champagne / L',
          size: 'L',
          colorName: 'Champagne',
          colorHex: '0xFFFAF7F3',
          price: 499900,
          originalPrice: 799900,
        ),
      ],
    ),
    Product(
      id: 'p2',
      handle: 'linen-tailored-blazer',
      title: 'Linen Tailored Blazer',
      brand: 'Clothsy Studio',
      description:
          'Structured yet lightweight, crafted from pure Normandy flax linen. Features structured lapels, tortoiseshell buttons, and a relaxed tailored fit that pairs effortlessly with tailored trousers or slip skirts.',
      price: 649900,
      originalPrice: 899900,
      category: 'Outerwear',
      rating: 4.8,
      reviewCount: 96,
      isFeatured: true,
      isNew: true,
      isTryonEligible: true,
      tags: ['Linen', 'Blazer', 'Tailored', 'Outerwear'],
      availableSizes: ['S', 'M', 'L', 'XL'],
      images: [
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v2_sand',
          title: 'Warm Sand / M',
          size: 'M',
          colorName: 'Warm Sand',
          colorHex: '0xFFD9CCA8',
          price: 649900,
          originalPrice: 899900,
        ),
        ProductVariant(
          id: 'v2_sage',
          title: 'Sage Olive / L',
          size: 'L',
          colorName: 'Sage Olive',
          colorHex: '0xFF2E7D5B',
          price: 649900,
          originalPrice: 899900,
        ),
      ],
    ),
    Product(
      id: 'p3',
      handle: 'pleated-slip-midi-gown',
      title: 'Pleated Slip Midi Gown',
      brand: 'Clothsy Edit',
      description:
          'Delicate micro-accordion pleats enhance every movement. Finished with a subtle asymmetric hemline and graceful silhouette.',
      price: 529900,
      originalPrice: 699900,
      category: 'Dresses',
      rating: 4.7,
      reviewCount: 65,
      isFeatured: true,
      isNew: false,
      isTryonEligible: true,
      tags: ['Pleated', 'Midi', 'Dresses'],
      availableSizes: ['XS', 'S', 'M', 'L'],
      images: [
        'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=900&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v3_lilac',
          title: 'Lilac Dusk / S',
          size: 'S',
          colorName: 'Lilac Dusk',
          colorHex: '0xFFB9A6E0',
          price: 529900,
          originalPrice: 699900,
        ),
      ],
    ),
    Product(
      id: 'p4',
      handle: 'cashmere-blend-knit-top',
      title: 'Cashmere Blend Knit Top',
      brand: 'Clothsy Essentials',
      description:
          'Supremely soft Mongolian cashmere spun with organic cotton. A timeless mock-neck silhouette designed for transitional season layering.',
      price: 349900,
      originalPrice: 499900,
      category: 'Tops',
      rating: 4.9,
      reviewCount: 112,
      isFeatured: false,
      isNew: true,
      isTryonEligible: true,
      tags: ['Knitwear', 'Cashmere', 'Tops'],
      availableSizes: ['XS', 'S', 'M', 'L', 'XL'],
      images: [
        'https://images.unsplash.com/photo-1576995853123-5a10305d93c0?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v4_ivory',
          title: 'Ivory / M',
          size: 'M',
          colorName: 'Ivory Cream',
          colorHex: '0xFFFAF7F3',
          price: 349900,
          originalPrice: 499900,
        ),
      ],
    ),
    Product(
      id: 'p5',
      handle: 'sculpted-leather-tote',
      title: 'Sculpted Leather Tote',
      brand: 'Clothsy Atelier',
      description:
          'Full-grain Italian calfskin leather handcrafted with architectural curved handles and gold-tone custom hardware.',
      price: 849900,
      originalPrice: 1199900,
      category: 'Bags',
      rating: 4.9,
      reviewCount: 78,
      isFeatured: true,
      isNew: false,
      isTryonEligible: false,
      tags: ['Leather', 'Bags', 'Accessories'],
      availableSizes: ['One Size'],
      images: [
        'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v5_black',
          title: 'Obsidian Black / One Size',
          size: 'One Size',
          colorName: 'Obsidian Black',
          colorHex: '0xFF1A1523',
          price: 849900,
          originalPrice: 1199900,
        ),
      ],
    ),
    Product(
      id: 'p6',
      handle: 'minimalist-ankle-strap-heels',
      title: 'Minimalist Ankle Strap Heels',
      brand: 'Clothsy Studio',
      description:
          '75mm sculptural stiletto heel with delicate ankle strap and cushioned memory foam insole for all-evening comfort.',
      price: 549900,
      originalPrice: 749900,
      category: 'Shoes',
      rating: 4.8,
      reviewCount: 53,
      isFeatured: false,
      isNew: true,
      isTryonEligible: false,
      tags: ['Shoes', 'Heels', 'Footwear'],
      availableSizes: ['36', '37', '38', '39', '40'],
      images: [
        'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=900&auto=format&fit=crop&q=80',
      ],
      variants: [
        ProductVariant(
          id: 'v6_nude',
          title: 'Champagne / 38',
          size: '38',
          colorName: 'Champagne',
          colorHex: '0xFFE7DFF6',
          price: 549900,
          originalPrice: 749900,
        ),
      ],
    ),
  ];

  @override
  Future<List<PromoBannerItem>> getFeaturedBanners() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      PromoBannerItem(
        id: 'b1',
        headline: 'New Season\nNew Styles',
        subtitle: 'Up to 40% off on latest collection',
        ctaText: 'Shop Now',
        imageUrl:
            'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=800&auto=format&fit=crop&q=80',
        deepLinkTarget: '/explore',
      ),
      PromoBannerItem(
        id: 'b2',
        headline: 'See Yourself In\nEvery Outfit',
        subtitle: 'Experience photorealistic AI Virtual Try-On',
        ctaText: 'Try It On',
        imageUrl:
            'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=800&auto=format&fit=crop&q=80',
        deepLinkTarget: '/tryon',
      ),
      PromoBannerItem(
        id: 'b3',
        headline: 'Exclusive Silk\nCollection',
        subtitle: 'Up to 40% off on signature pieces',
        ctaText: 'Shop Silk',
        imageUrl:
            'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=800&auto=format&fit=crop&q=80',
        deepLinkTarget: '/explore',
      ),
    ];
  }

  @override
  Future<List<ProductCollection>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return const [
      ProductCollection(
        id: 'col_all',
        handle: 'all',
        title: 'All',
        icon: Icons.checkroom_rounded,
      ),
      ProductCollection(
        id: 'col_men',
        handle: 'men',
        title: 'Men',
        icon: Icons.man_outlined,
      ),
      ProductCollection(
        id: 'col_women',
        handle: 'women',
        title: 'Women',
        icon: Icons.woman_outlined,
      ),
      ProductCollection(
        id: 'col_shoes',
        handle: 'shoes',
        title: 'Shoes',
        icon: Icons.roller_skating_outlined,
      ),
      ProductCollection(
        id: 'col_bags',
        handle: 'bags',
        title: 'Bags',
        icon: Icons.shopping_bag_outlined,
      ),
    ];
  }

  @override
  Future<List<Product>> getProducts({
    String? category,
    int page = 1,
    int limit = 20,
    String? sortBy,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    var results = List<Product>.from(_products);

    if (category != null && category.toLowerCase() != 'all') {
      final cat = category.toLowerCase();
      results = results.where((p) {
        final pCat = p.category.toLowerCase();
        if (pCat == cat) return true;
        if (cat == 'men' &&
            (pCat == 'men' || p.tags.any((t) => t.toLowerCase() == 'men'))) {
          return true;
        }
        if (cat == 'women' &&
            (pCat == 'women' ||
                pCat == 'dresses' ||
                pCat == 'outerwear' ||
                p.tags.any((t) => t.toLowerCase() == 'women'))) {
          return true;
        }
        if (cat == 'shoes' && pCat == 'shoes') return true;
        if (cat == 'bags' && pCat == 'bags') return true;
        return p.tags.any((t) => t.toLowerCase() == cat);
      }).toList();
    }

    if (sortBy == 'price_low_high') {
      results.sort((a, b) => a.price.compareTo(b.price));
    } else if (sortBy == 'price_high_low') {
      results.sort((a, b) => b.price.compareTo(a.price));
    } else if (sortBy == 'popular') {
      results.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    }

    return results;
  }

  @override
  Future<Product?> getProductById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _products.firstWhere((p) => p.id == id || p.handle == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    return _products.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Future<List<Product>> getBestPicks() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _products.where((p) => p.isFeatured).toList();
  }

  @override
  Future<List<Product>> getRecommendations(String productId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _products.where((p) => p.id != productId).take(3).toList();
  }
}
