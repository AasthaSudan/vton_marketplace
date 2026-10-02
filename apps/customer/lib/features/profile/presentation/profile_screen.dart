import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_radius.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/buttons/pressable_scale.dart';
import 'package:clothsy_core/shared/widgets/buttons/primary_button.dart';
import 'package:clothsy_core/shared/widgets/buttons/secondary_button.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_bottom_sheet.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/shared/widgets/inputs/clothsy_text_field.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../notifications/presentation/providers/notifications_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _openEditProfileSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final nameController = TextEditingController(
      text: user?.name ?? 'Aastha Sudan',
    );
    final emailController = TextEditingController(
      text: user?.email ?? 'aastha@example.com',
    );
    final phoneController = TextEditingController(
      text: user?.phone ?? '+91 98765 43210',
    );

    ClothsyBottomSheet.show(
      context: context,
      title: 'Edit profile',
      subtitle: 'Update your contact and membership details',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ClothsyTextField(label: 'Full Name', controller: nameController),
            const SizedBox(height: 14),
            ClothsyTextField(
              label: 'Email Address',
              controller: emailController,
            ),
            const SizedBox(height: 14),
            ClothsyTextField(
              label: 'Mobile Phone',
              controller: phoneController,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Save Profile Changes',
              onPressed: () {
                ref
                    .read(authProvider.notifier)
                    .updateProfile(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                    );
                Navigator.pop(context);
                ClothsySnackbar.show(
                  context,
                  message: 'Profile updated successfully',
                  type: SnackbarType.success,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Account',
          style: AppTypography.h3(color: ctx.colors.error),
        ),
        content: Text(
          'Are you sure you wish to permanently delete your Clothsy account? All orders, saved models, and rewards will be erased.',
          style: AppTypography.body(color: ctx.colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.caption(color: ctx.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).deleteAccount();
              ClothsySnackbar.show(
                ctx,
                message: 'Account permanently erased',
                type: SnackbarType.info,
              );
            },
            child: Text(
              'Delete Account',
              style: AppTypography.caption(
                color: ctx.colors.error,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: colors.border.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.accentSoft,
                  child: Text(
                    (user?.name.isNotEmpty == true)
                        ? user!.name[0].toUpperCase()
                        : 'C',
                    style: AppTypography.h2(color: colors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name.isNotEmpty == true
                            ? user!.name
                            : 'Clothsy Shopper',
                        style: AppTypography.h3(color: colors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone.isNotEmpty == true
                            ? user!.phone
                            : (user?.email.isNotEmpty == true
                                  ? user!.email
                                  : 'Sign in for member perks'),
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          user?.memberTier ?? 'Clothsy Member',
                          style: AppTypography.label(
                            color: colors.primary,
                            weight: FontWeight.w700,
                          ).copyWith(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (auth.isAuthenticated)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    onPressed: () => _openEditProfileSheet(context, ref),
                  )
                else
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: Text(
                      'Sign In',
                      style: AppTypography.caption(
                        color: colors.primary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Menu Options
          _buildMenuItem(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'My Orders',
            subtitle: 'Track live status, invoices & cancellations',
            onTap: () => context.push('/orders'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.favorite_outline_rounded,
            title: 'Wishlist',
            subtitle: 'Saved favourites, price-drop & restock alerts',
            onTap: () => context.push('/wishlist'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.location_on_outlined,
            title: 'Delivery Addresses',
            subtitle: 'Manage saved delivery and billing locations',
            onTap: () => context.push('/addresses'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Order milestones, offers & style alerts',
            badgeCount: unreadNotifs,
            onTap: () => context.push('/notifications'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.history_edu_outlined,
            title: 'My Try-On Look History',
            subtitle: 'Revisit past styled looks & outfits',
            onTap: () => context.push('/tryon/history'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.auto_awesome_outlined,
            title: 'Virtual Try-On Studio',
            subtitle: 'Your photos, try-on credits and saved looks',
            onTap: () => context.go('/tryon'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.palette_outlined,
            title: 'Design Tokens',
            subtitle: 'Colors, typography & component reference',
            onTap: () => context.push('/gallery'),
          ),

          _buildMenuItem(
            context,
            icon: Icons.help_outline_rounded,
            title: 'Help & Stylist Concierge',
            subtitle: '24/7 dedicated support via WhatsApp & chat',
            onTap: () {
              ClothsySnackbar.show(
                context,
                message:
                    'Help centre is coming soon. Our team will be with you shortly.',
                type: SnackbarType.info,
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.policy_outlined,
            title: 'Privacy Policy & Terms',
            subtitle: 'Shopper data privacy & returns policy',
            onTap: () {
              ClothsySnackbar.show(
                context,
                message: 'Viewing Clothsy shopper privacy policy',
                type: SnackbarType.info,
              );
            },
          ),
          const SizedBox(height: 16),

          // Sign Out & Delete Account
          if (auth.isAuthenticated) ...[
            SecondaryButton(
              text: 'Sign Out',
              onPressed: () {
                ref.read(authProvider.notifier).signOut();
                ClothsySnackbar.show(
                  context,
                  message: 'You have been signed out',
                  type: SnackbarType.info,
                );
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => _confirmDeleteAccount(context, ref),
                child: Text(
                  'Delete Account',
                  style: AppTypography.caption(
                    color: colors.error,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: colors.border.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium(
                        color: colors.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: AppTypography.label(
                      color: colors.onPrimary,
                    ).copyWith(fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
