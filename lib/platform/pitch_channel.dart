import 'dart:async';
import 'package:flutter/services.dart';

class PitchData {
  final double pitch;
  final List<double> samples;

  PitchData(this.pitch, this.samples);
}

class PitchChannel {
  static const _method = MethodChannel('pitchscope/method');
  static const _event = EventChannel('pitchscope/event');

  static double _lastPitch = 0;
  static double _smoothedPitch = 0;
  static DateTime _lastEmitTime = DateTime.now();

  static const double _smoothingFactor = 0.12; 

  static Stream<PitchData> stream =
      _event.receiveBroadcastStream().map((event) {
    final map = Map<String, dynamic>.from(event as Map);

    final rawPitch = (map['pitch'] as num?)?.toDouble() ?? 0.0;
    final rawSamples = map['samples'] as List<dynamic>?;

    if (rawPitch <= 0) {
      return PitchData(0.0, const []);
    }

    if ((rawPitch - _lastPitch).abs() < 1) {
      return PitchData(0.0, const []);
    }
    _lastPitch = rawPitch;

    _smoothedPitch = _smoothedPitch +
        _smoothingFactor * (rawPitch - _smoothedPitch);

    if (DateTime.now()
            .difference(_lastEmitTime)
            .inMilliseconds <
        40) {
      return PitchData(0.0, const []);
    }

    _lastEmitTime = DateTime.now();

    return PitchData(
      _smoothedPitch,
      rawSamples == null
          ? const []
          : rawSamples.map((e) => (e as num).toDouble()).toList(),
    );
  }).where((data) => data.pitch > 0); 

  static Future<void> start() => _method.invokeMethod('start');
  static Future<void> stop() => _method.invokeMethod('stop');
}
