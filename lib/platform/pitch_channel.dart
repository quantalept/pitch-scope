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

  static Stream<PitchData> stream =
      _event.receiveBroadcastStream().map((event) {
    final map = Map<String, dynamic>.from(event as Map);

    final rawSamples = map['samples'] as List<dynamic>?;

    return PitchData(
      (map['pitch'] as num?)?.toDouble() ?? 0.0,
      rawSamples == null
          ? <double>[]
          : rawSamples.map((e) => (e as num).toDouble()).toList(),
    );
  });

  static Future<void> start() => _method.invokeMethod('start');
  static Future<void> stop() => _method.invokeMethod('stop');
}