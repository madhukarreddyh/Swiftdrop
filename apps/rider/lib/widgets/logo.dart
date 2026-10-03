import 'package:flutter/material.dart';

import '../theme.dart';

/// SwiftDrop mark: a parcel box with a lightning bolt, drawn in code.
/// Used on the splash screen and in headers.
class SwiftDropLogo extends StatelessWidget {
  const SwiftDropLogo({super.key, this.size = 96, this.boxColor});

  final double size;
  final Color? boxColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(boxColor ?? AppColors.primary),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Rounded parcel box.
    final boxPaint = Paint()..color = color;
    final boxRect = RRect.fromLTRBR(
      w * 0.12,
      h * 0.28,
      w * 0.88,
      h * 0.88,
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(boxRect, boxPaint);

    // Tape strip across the top of the box.
    final tapePaint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawRect(
      Rect.fromLTRB(w * 0.12, h * 0.28, w * 0.88, h * 0.40),
      tapePaint,
    );

    // Lightning bolt cut out of the box (drawn in background color).
    final boltPaint = Paint()..color = Colors.white;
    final bolt = Path()
      ..moveTo(w * 0.56, h * 0.34)
      ..lineTo(w * 0.36, h * 0.62)
      ..lineTo(w * 0.50, h * 0.62)
      ..lineTo(w * 0.44, h * 0.82)
      ..lineTo(w * 0.64, h * 0.52)
      ..lineTo(w * 0.50, h * 0.52)
      ..close();
    canvas.drawPath(bolt, boltPaint);

    // Motion lines to the left — speed.
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.02, h * 0.45), Offset(w * 0.10, h * 0.45),
        linePaint);
    canvas.drawLine(Offset(w * 0.00, h * 0.60), Offset(w * 0.10, h * 0.60),
        linePaint);
    canvas.drawLine(Offset(w * 0.02, h * 0.75), Offset(w * 0.10, h * 0.75),
        linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
