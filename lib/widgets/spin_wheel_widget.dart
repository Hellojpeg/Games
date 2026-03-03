import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/spin_reward.dart';

/// A custom-painted spin wheel that displays [rewards] as coloured segments
/// and animates a rotation to land on [targetIndex].
///
/// The caller controls the [AnimationController]; this widget only paints.
class SpinWheelWidget extends StatelessWidget {
  final List<SpinReward> rewards;

  /// 0-based index of the reward the wheel should stop on.
  final int targetIndex;

  /// Animation value in range [0, 1]; maps to rotation angle.
  final Animation<double> animation;

  /// Diameter of the wheel in logical pixels.
  final double size;

  const SpinWheelWidget({
    super.key,
    required this.rewards,
    required this.targetIndex,
    required this.animation,
    this.size = 300,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _WheelPainter(
              rewards: rewards,
              rotationAngle: animation.value * 2 * math.pi,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// Computes the total rotation angle needed to stop on [targetIndex] after
/// [fullRotations] complete turns, with a randomised spin duration offset.
///
/// [fullRotations] should be between 5 and 8 for a visually satisfying spin.
double computeTargetAngle({
  required int targetIndex,
  required int rewardCount,
  int fullRotations = 6,
}) {
  final segmentAngle = 2 * math.pi / rewardCount;
  // Centre of the target segment, offset by half a segment so the pointer
  // lands in the middle of the slice.
  final targetAngle = targetIndex * segmentAngle + segmentAngle / 2;
  // Total rotation: full turns + angle to land on target.
  return fullRotations * 2 * math.pi + targetAngle;
}

// ---------------------------------------------------------------------------
// Internal painter
// ---------------------------------------------------------------------------

class _WheelPainter extends CustomPainter {
  final List<SpinReward> rewards;
  final double rotationAngle;

  _WheelPainter({required this.rewards, required this.rotationAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * math.pi / rewards.length;

    // Start from the top (–π/2) so segment 0 begins at 12 o'clock, then
    // add the running rotation so segments move.
    final startOffset = -math.pi / 2 + rotationAngle;

    final segmentPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2;

    for (int i = 0; i < rewards.length; i++) {
      final startAngle = startOffset + i * segmentAngle;
      segmentPaint.color = rewards[i].color;

      // Fill segment.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        segmentPaint,
      );

      // Segment border.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Label text – draw at the midpoint of the segment arc.
      _drawSegmentLabel(
        canvas: canvas,
        center: center,
        radius: radius,
        startAngle: startAngle,
        segmentAngle: segmentAngle,
        reward: rewards[i],
      );
    }

    // Outer ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 4,
    );

    // Centre hub.
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey.shade400
        ..strokeWidth = 2,
    );
  }

  void _drawSegmentLabel({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double startAngle,
    required double segmentAngle,
    required SpinReward reward,
  }) {
    final midAngle = startAngle + segmentAngle / 2;
    // Position icon + text at 65 % of the radius.
    final textRadius = radius * 0.65;
    final labelX = center.dx + textRadius * math.cos(midAngle);
    final labelY = center.dy + textRadius * math.sin(midAngle);

    canvas.save();
    canvas.translate(labelX, labelY);
    canvas.rotate(midAngle + math.pi / 2);

    final textPainter = TextPainter(
      text: TextSpan(
        text: reward.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 60);

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle ||
      oldDelegate.rewards != rewards;
}

/// Fixed pointer / arrow at the top of the wheel indicating the winning slot.
class SpinWheelPointer extends StatelessWidget {
  const SpinWheelPointer({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 32),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.red.shade700);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => false;
}
