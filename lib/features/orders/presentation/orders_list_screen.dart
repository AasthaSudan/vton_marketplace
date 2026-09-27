import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/buttons/clothsy_icon_button.dart';
import '../../../shared/widgets/buttons/pressable_scale.dart';
import '../../../shared/widgets/feedback/empty_state_view.dart';
import '../domain/entities/order.dart';
import 'providers/order_providers.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  String _selectedFilter = 'All'; // All, Active, Delivered, Cancelled

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final orders = ref.watch(ordersProvider);

    final filteredOrders = orders.where((o) {
      if (_selectedFilter == 'Active') {
        return o.status == OrderStatus.placed ||
            o.status == OrderStatus.packed ||
            o.status == OrderStatus.shipped ||
            o.status == OrderStatus.outForDelivery;
      } else if (_selectedFilter == 'Delivered') {
        return o.status == OrderStatus.delivered;
      } else if (_selectedFilter == 'Cancelled') {
        return o.status == OrderStatus.cancelled;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: AppTypography.h3(color: colors.textPrimary),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ClothsyIconButton(
            size: 38,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: colors.primary,
            ),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs (All, Active, Delivered, Cancelled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: ['All', 'Active', 'Delivered', 'Cancelled'].map((
                filter,
              ) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PressableScale(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.border,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: AppTypography.caption(
                          color: isSelected
                              ? colors.onPrimary
                              : colors.textPrimary,
                          weight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Orders List
          Expanded(
            child: filteredOrders.isEmpty
                ? EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: 'No Orders Found',
                    message:
                        'You have no $_selectedFilter orders in your history.',
                    actionText: 'Explore Collection',
                    onActionPressed: () => context.go('/explore'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderCard(context, order);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final colors = context.colors;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.orderDate);

    Color statusColor;
    switch (order.status) {
      case OrderStatus.delivered:
        statusColor = colors.success;
        break;
      case OrderStatus.cancelled:
        statusColor = colors.error;
        break;
      case OrderStatus.shipped:
      case OrderStatus.outForDelivery:
        statusColor = colors.accent;
        break;
      default:
        statusColor = colors.primary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressableScale(
        onTap: () => context.push('/orders/${order.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: colors.border.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Number and Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber,
                    style: AppTypography.bodyMedium(weight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      order.status.label.toUpperCase(),
                      style: AppTypography.label(
                        color: statusColor,
                        weight: FontWeight.w700,
                      ).copyWith(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: AppTypography.caption(
                  color: colors.textSecondary,
                ).copyWith(fontSize: 11),
              ),
              const SizedBox(height: 12),
              Divider(color: colors.border.withOpacity(0.5)),
              const SizedBox(height: 12),

              // Items Row
              Row(
                children: [
                  // Thumbnails row (up to 3 items)
                  ...order.items.take(3).map((item) {
                    return Container(
                      width: 50,
                      height: 58,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: colors.surfaceMuted,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl:
                            item.variant.imageUrl ?? item.product.primaryImage,
                        fit: BoxFit.cover,
                      ),
                    );
                  }),
                  if (order.items.length > 3)
                    Container(
                      width: 50,
                      height: 58,
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '+${order.items.length - 3}',
                          style: AppTypography.caption(weight: FontWeight.w700),
                        ),
                      ),
                    ),
                  const Spacer(),

                  // Amount and arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(order.total),
                        style: AppTypography.h3(color: colors.textPrimary),
                      ),
                      Text(
                        '${order.items.length} ${order.items.length == 1 ? "item" : "items"}',
                        style: AppTypography.caption(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: colors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
