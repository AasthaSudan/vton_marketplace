import 'package:flutter/material.dart';
import 'package:clothsy_core/core/theme/app_theme.dart';
import 'package:clothsy_core/shared/widgets/navigation/panel_shell.dart';

/// The Seller Panel lets brands of every size run their store on Clothsy
/// (Brand Blueprint, Part 07). Sections follow the seller sitemap (fig. 30).
const List<PanelSection> sellerSections = [
  PanelSection(
    title: 'Dashboard',
    icon: Icons.dashboard_outlined,
    items: [
      'Sales & revenue',
      "Today's orders",
      'Alerts & tasks',
      'Performance score',
    ],
    phase: 'Phase 2',
  ),
  PanelSection(
    title: 'Onboarding',
    icon: Icons.verified_user_outlined,
    items: [
      'Registration',
      'Business & tax details (GST, PAN)',
      'KYC & bank details',
      'Brand assets',
      'Verification status',
    ],
    phase: 'Phase 2',
  ),
  PanelSection(
    title: 'Store',
    icon: Icons.storefront_outlined,
    items: ['Storefront design', 'Collections', 'Brand story', 'Policies'],
    phase: 'Phase 2',
  ),
  PanelSection(
    title: 'Products',
    icon: Icons.checkroom_outlined,
    items: [
      'Add / edit products',
      'Drafts',
      'Approval status',
      'Bulk upload',
      'Try-On ready images',
    ],
    phase: 'Phase 2',
  ),
  PanelSection(
    title: 'Inventory',
    icon: Icons.inventory_2_outlined,
    items: [
      'Stock by SKU',
      'Low-stock alerts',
      'Stock adjustments',
      'Inventory history',
    ],
    phase: 'Phase 2',
  ),
  PanelSection(
    title: 'Orders & returns',
    icon: Icons.local_shipping_outlined,
    items: ['New orders', 'Packing & labels', 'Pickups & tracking', 'Returns'],
    phase: 'Phase 2',
  ),
  PanelSection(
    title: 'Growth',
    icon: Icons.campaign_outlined,
    items: [
      'Coupons & offers',
      'Flash sales',
      'Campaigns',
      'Reviews & replies',
    ],
    phase: 'Phase 4',
  ),
  PanelSection(
    title: 'Money & insights',
    icon: Icons.account_balance_wallet_outlined,
    items: ['Analytics', 'Reports', 'Payouts', 'Statements'],
    phase: 'Phase 2',
  ),
];

void main() {
  runApp(const ClothsySellerApp());
}

class ClothsySellerApp extends StatelessWidget {
  const ClothsySellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clothsy Seller Panel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const PanelShell(
        panelName: 'Seller Panel',
        sections: sellerSections,
      ),
    );
  }
}
