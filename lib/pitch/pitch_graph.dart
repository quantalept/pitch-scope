import 'dart:async';
import 'package:flutter/material.dart';

double hzToY(
  double hz,
  double minHz,
  double maxHz,
  double height,
) {
  final clamped = hz.clamp(minHz, maxHz);
  return height -
      ((clamped - minHz) / (maxHz - minHz)) * height;
}

class PitchGraph extends StatefulWidget {
  final Stream<double> pitchStream;
  final double minHz;
  final double maxHz;

  const PitchGraph({
    super.key,
    required this.pitchStream,
    this.minHz = 60,
    this.maxHz = 1000,
  });

  @override
  State<PitchGraph> createState() => _PitchGraphState();
}

class _PitchGraphState extends State<PitchGraph> {
  static const int maxPoints = 200;

  final List<double> _pitches = [];

  double _lastPitch = 0;
  double _smoothedPitch = 0;

  final double _smoothingFactor = 0.18;
  DateTime _lastUpdate = DateTime.now();

  late StreamSubscription<double> _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = widget.pitchStream.listen((hz) {
      if (!mounted) return;
      if (hz <= 0) return; // ignore silence

      // Ignore tiny jitter
      if ((hz - _lastPitch).abs() < 2) return;
      _lastPitch = hz;

      // Initialize smoothing properly
      if (_smoothedPitch == 0) {
        _smoothedPitch = hz;
      } else {
        _smoothedPitch =
            _smoothedPitch + _smoothingFactor * (hz - _smoothedPitch);
      }

      // Limit to ~25 FPS
      final now = DateTime.now();
      if (now.difference(_lastUpdate).inMilliseconds < 40) {
        return;
      }
      _lastUpdate = now;

      setState(() {
        _pitches.add(_smoothedPitch);

        if (_pitches.length > maxPoints) {
          _pitches.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(
            constraints.maxWidth,
            constraints.maxHeight,
          ),
          painter: PitchPainter(
            pitches: _pitches,
            maxPoints: maxPoints,
            minHz: widget.minHz,
            maxHz: widget.maxHz,
          ),
        );
      },
    );
  }
}

class PitchPainter extends CustomPainter {
  final List<double> pitches;
  final int maxPoints;
  final double minHz;
  final double maxHz;

  PitchPainter({
    required this.pitches,
    required this.maxPoints,
    required this.minHz,
    required this.maxHz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121212),
    );

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;

    final gridHz = [82, 110, 147, 196, 247, 330, 440, 659];

    for (final hz in gridHz) {
      final y = hzToY(
        hz.toDouble(),
        minHz,
        maxHz,
        size.height,
      );

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    if (pitches.length < 2) return;

    final pitchPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final dx = size.width / (maxPoints - 1);

    for (int i = 1; i < pitches.length; i++) {
      canvas.drawLine(
        Offset(
          (i - 1) * dx,
          hzToY(
            pitches[i - 1],
            minHz,
            maxHz,
            size.height,
          ),
        ),
        Offset(
          i * dx,
          hzToY(
            pitches[i],
            minHz,
            maxHz,
            size.height,
          ),
        ),
        pitchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
