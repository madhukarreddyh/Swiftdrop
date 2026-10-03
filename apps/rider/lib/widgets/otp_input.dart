import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// 4-box OTP input with auto-advance, backspace navigation and paste support.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 4,
    this.onCompleted,
    this.onChanged,
  });

  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get code => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    widget.onChanged?.call('');
  }

  void _onChanged(int index, String value) {
    // Handle paste of the full code into the first box.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0;
          i < digits.length && i < widget.length;
          i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= widget.length) {
        _nodes.last.unfocus();
      } else {
        _nodes[digits.length].requestFocus();
      }
    } else if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Backspace on empty box moves to the previous one.
      _nodes[index - 1].requestFocus();
    }
    final current = code;
    widget.onChanged?.call(current);
    if (current.length == widget.length &&
        !_controllers.any((c) => c.text.isEmpty)) {
      widget.onCompleted?.call(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 60,
          height: 68,
          child: TextField(
            key: ValueKey('otp-box-$i'),
            controller: _controllers[i],
            focusNode: _nodes[i],
            autofocus: i == 0,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: (v) => _onChanged(i, v),
          ),
        );
      }),
    );
  }
}
