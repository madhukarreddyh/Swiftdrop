import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Circular countdown ring used on the incoming-order card.
/// Calls [onTimeout] when the countdown reaches zero.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.duration,
    required this.onTimeout,
    this.size = 64,
  });

  final Duration duration;
  final VoidCallback onTimeout;
  final double size;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onTimeout();
      });
    _controller.forward();
    // Safety net in case the animation ticker is throttled.
    _fallback = Timer(widget.duration + const Duration(seconds: 2), () {
      if (mounted) widget.onTimeout();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _fallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final remaining = widget.duration * (1 - _controller.value);
          final seconds = remaining.inSeconds + 1;
          return CustomPaint(
            painter: _RingPainter(progress: 1 - _controller.value),
            child: Center(
              child: Text(
                '$seconds',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bg = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
