import 'package:flutter/material.dart';

class ProductCollection {
  final String id;
  final String handle;
  final String title;
  final String? description;
  final String? imageUrl;
  final IconData? icon;

  const ProductCollection({
    required this.id,
    required this.handle,
    required this.title,
    this.description,
    this.imageUrl,
    this.icon,
  });
}
