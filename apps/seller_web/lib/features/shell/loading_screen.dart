import 'package:clothsy_core/shared/widgets/feedback/error_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/seller_repository.dart';

/// While the panel finds out which store you work for (or why it can't).
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(currentSellerProvider);
    return Scaffold(
      body: seller.hasError
          ? ErrorStateView(
              title: "Couldn't open your store",
              message: seller.error is SellerFailure
                  ? (seller.error! as SellerFailure).message
                  : 'Please check your connection and try again.',
              onRetry: () => ref.invalidate(currentSellerProvider),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
