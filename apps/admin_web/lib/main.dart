import 'package:flutter/material.dart';
import 'package:clothsy_core/core/theme/app_theme.dart';
import 'package:clothsy_core/shared/widgets/navigation/panel_shell.dart';

/// The Admin Panel gives the Clothsy team visibility and control, with
/// role-based access (Brand Blueprint, Part 08). Sections follow the admin
/// sitemap (fig. 38).
const List<PanelSection> adminSections = [
  PanelSection(
    title: 'Command center',
    icon: Icons.space_dashboard_outlined,
    items: [
      'Dashboard: GMV, orders, revenue',
      'Users & sellers',
      'Operational alerts',
    ],
    phase: 'Phase 3',
  ),
  PanelSection(
    title: 'People',
    icon: Icons.groups_outlined,
    items: [
      'Users: search, verify, suspend',
      'Sellers: applications, KYC',
      'Seller performance',
    ],
    phase: 'Phase 3',
  ),
  PanelSection(
    title: 'Catalogue',
    icon: Icons.fact_check_outlined,
    items: ['Product moderation', 'Categories', 'Brands', 'Policy & IP review'],
    phase: 'Phase 3',
  ),
  PanelSection(
    title: 'Orders & money',
    icon: Icons.payments_outlined,
    items: ['Global orders', 'Payments', 'Refunds', 'Commissions', 'Payouts'],
    phase: 'Phase 3',
  ),
  PanelSection(
    title: 'Care',
    icon: Icons.support_agent_outlined,
    items: ['Returns', 'Disputes', 'Support tickets'],
    phase: 'Phase 3',
  ),
  PanelSection(
    title: 'Growth',
    icon: Icons.trending_up_rounded,
    items: [
      'Coupons',
      'Coins & rewards',
      'Referrals',
      'CMS: banners, collections, homepage',
    ],
    phase: 'Phase 4',
  ),
  PanelSection(
    title: 'Trust & safety',
    icon: Icons.shield_outlined,
    items: ['Fraud monitoring', 'Review moderation', 'Audit history'],
    phase: 'Phase 3',
  ),
  PanelSection(
    title: 'Insights & settings',
    icon: Icons.settings_outlined,
    items: ['Analytics & reports', 'Roles & access', 'Platform settings'],
    phase: 'Phase 3',
  ),
];

void main() {
  runApp(const ClothsyAdminApp());
}

class ClothsyAdminApp extends StatelessWidget {
  const ClothsyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clothsy Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const PanelShell(panelName: 'Admin Panel', sections: adminSections),
    );
  }
}
