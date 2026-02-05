import 'package:flutter/material.dart';

class PitchPainter extends CustomPainter {
  final List<double> pitchHistory;
  final int minMidi;
  final int maxMidi;

  PitchPainter({
    required this.pitchHistory,
    required this.minMidi,
    required this.maxMidi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 🔴 BACKGROUND — THIS REMOVES WHITE
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121212),
    );

    if (pitchHistory.length < 2) return;

    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    for (int i = 0; i < pitchHistory.length; i++) {
      // FIX: last point reaches right edge
      final x = size.width * i / (pitchHistory.length - 1);

      final normalized =
          (pitchHistory[i] - minMidi) / (maxMidi - minMidi);

      final y = size.height * (1 - normalized.clamp(0.0, 1.0));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PitchPainter oldDelegate) {
    return oldDelegate.pitchHistory != pitchHistory;
  }
}
