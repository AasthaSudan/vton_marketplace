import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';
import 'package:clothsy_core/shared/widgets/feedback/clothsy_snackbar.dart';
import 'package:clothsy_core/shared/widgets/feedback/error_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/seller_repository.dart';

final _dateFormat = DateFormat('d MMM yyyy');
final _dateTimeFormat = DateFormat('d MMM, h:mm a');

String formatDate(DateTime? d) => d == null ? '—' : _dateFormat.format(d);
String formatDateTime(DateTime? d) =>
    d == null ? '—' : _dateTimeFormat.format(d);

/// A panel page: title, optional subtitle and actions, then content, kept to
/// a readable width.
class PanelPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  const PanelPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final list = ListView(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 16 : 32,
        vertical: narrow ? 16 : 28,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.h1(color: colors.textPrimary),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: AppTypography.body(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (actions.isNotEmpty)
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class PanelCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const PanelCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: AppTypography.h3(color: colors.textPrimary),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// A number with its label, e.g. "New orders 3".
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.color,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = color ?? colors.primary;
    return SizedBox(
      width: 200,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: tone),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.label(color: colors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(value, style: AppTypography.h2(color: tone)),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    style: AppTypography.caption(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum Tone { neutral, info, success, warning, danger }

class StatusChip extends StatelessWidget {
  final String label;
  final Tone tone;

  const StatusChip(this.label, {super.key, this.tone = Tone.neutral});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tone) {
      Tone.neutral => colors.textSecondary,
      Tone.info => colors.primary,
      Tone.success => colors.success,
      Tone.warning => colors.warning,
      Tone.danger => colors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: AppTypography.label(color: color)),
    );
  }
}

/// Loading / error / data for an [AsyncValue].
class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorStateView(
        message: error is SellerFailure
            ? error.message
            : 'This could not be loaded. Please try again.',
        onRetry: onRetry,
      ),
    );
  }
}

/// A labelled text field for panel forms.
class FieldBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final int maxLines;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final double width;
  final bool obscure;
  final TextCapitalization capitalization;

  const FieldBox({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.maxLines = 1,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.width = 340,
    this.obscure = false,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: obscure ? 1 : maxLines,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: capitalization,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Fields laid out in rows that wrap on narrow screens.
class FieldWrap extends StatelessWidget {
  final List<Widget> children;

  const FieldWrap({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 16, runSpacing: 16, children: children);
}

void showFailure(BuildContext context, Object error) {
  ClothsySnackbar.show(
    context,
    message: error is SellerFailure
        ? error.message
        : 'Something went wrong. Please try again.',
    type: SnackbarType.error,
  );
}

void showDone(BuildContext context, String message) {
  ClothsySnackbar.show(context, message: message, type: SnackbarType.success);
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Back'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: context.colors.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for one line of text (e.g. a cancellation reason); null if dismissed.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String confirmText = 'OK',
  String? initial,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    label: label,
    confirmText: confirmText,
    initial: initial,
  ),
);

/// Owns its controller, so it is only disposed once the dialog has closed.
class _TextPrompt extends StatefulWidget {
  final String title;
  final String label;
  final String confirmText;
  final String? initial;

  const _TextPrompt({
    required this.title,
    required this.label,
    required this.confirmText,
    this.initial,
  });

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

/// A table that scrolls sideways on narrow screens.
class ScrollTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const ScrollTable({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: AppTypography.label(
          color: context.colors.textSecondary,
        ),
        columnSpacing: 28,
        columns: columns,
        rows: rows,
      ),
    );
  }
}
