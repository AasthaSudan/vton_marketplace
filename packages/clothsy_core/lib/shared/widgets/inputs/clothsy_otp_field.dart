import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

class ClothsyOtpField extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  const ClothsyOtpField({
    super.key,
    this.length = 4,
    this.onCompleted,
    this.onChanged,
  });

  @override
  State<ClothsyOtpField> createState() => _ClothsyOtpFieldState();
}

class _ClothsyOtpFieldState extends State<ClothsyOtpField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }

    final otp = _currentOtp;
    widget.onChanged?.call(otp);
    if (otp.length == widget.length) {
      widget.onCompleted?.call(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        final isFilled = _controllers[index].text.isNotEmpty;

        return Container(
          width: 56,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: AppTypography.h2(color: colors.textPrimary),
            cursorColor: colors.primary,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: isFilled ? colors.surfaceMuted : colors.surface,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: AppRadius.cardRadius,
                borderSide: BorderSide(color: colors.border, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.cardRadius,
                borderSide: BorderSide(
                  color: isFilled ? colors.primary : colors.border,
                  width: isFilled ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.cardRadius,
                borderSide: BorderSide(color: colors.primary, width: 2.0),
              ),
            ),
            onChanged: (value) => _onChanged(value, index),
          ),
        );
      }),
    );
  }
}
