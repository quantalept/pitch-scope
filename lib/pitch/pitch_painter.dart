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
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121212),
    );

    if (pitchHistory.length < 2) return;

    final paint = Paint()
      ..color = Colors.cyanAccent   
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();

    bool started = false;
    double? lastY;

    for (int i = 0; i < pitchHistory.length; i++) {
      final midi = pitchHistory[i];

      if (midi <= 0) {
        started = false;
        lastY = null;
        continue;
      }

      final x = size.width * i / (pitchHistory.length - 1);

      final normalized =
          (midi - minMidi) / (maxMidi - minMidi);

      final y =
          size.height * (1 - normalized.clamp(0.0, 1.0));

      if (lastY != null && (y - lastY!).abs() < 1.5) continue;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }

      lastY = y;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PitchPainter oldDelegate) {
    return oldDelegate.pitchHistory != pitchHistory ||
        oldDelegate.minMidi != minMidi ||
        oldDelegate.maxMidi != maxMidi;
  }
}
