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
    this.length = 6,
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
    if (value.length > 1) {
      _spread(value, index);
      return;
    }
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

    _report();
  }

  /// A pasted or SMS-autofilled code (or a digit typed into a filled box)
  /// arrives in one box: spread it over this box and the ones after it.
  void _spread(String digits, int index) {
    var i = index;
    for (final digit in digits.split('')) {
      if (i == widget.length) break;
      _controllers[i].text = digit;
      i++;
    }
    if (i < widget.length) {
      _focusNodes[i].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    setState(() {});
    _report();
  }

  void _report() {
    final otp = _currentOtp;
    widget.onChanged?.call(otp);
    if (otp.length == widget.length) {
      widget.onCompleted?.call(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Boxes shrink to fit: six 56 px boxes do not fit a 320 px phone.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final available = constraints.maxWidth - gap * widget.length;
        final boxWidth = (available / widget.length).clamp(36.0, 56.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            return _box(colors, index, boxWidth, gap);
          }),
        );
      },
    );
  }

  Widget _box(
    ClothsyColorExtension colors,
    int index,
    double width,
    double gap,
  ) {
    final isFilled = _controllers[index].text.isNotEmpty;

    return Container(
      width: width,
      height: 64,
      margin: EdgeInsets.symmetric(horizontal: gap / 2),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        // More than one digit is allowed in so a whole pasted or
        // autofilled code can be spread over the boxes (_spread).
        autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
        style: AppTypography.h2(color: colors.textPrimary),
        cursorColor: colors.primary,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(widget.length),
        ],
        decoration: InputDecoration(
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
  }
}
