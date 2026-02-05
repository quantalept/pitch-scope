import 'dart:math';

double hzToY(double hz, double minHz, double maxHz, double height) {
  hz = hz.clamp(minHz, maxHz);
  final normalized = (hz - minHz) / (maxHz - minHz);
  return height - (normalized * height);
}