import 'dart:async';
import 'package:flutter/services.dart';

class PitchService {
  static const EventChannel _event =
      EventChannel('pitchscope/event');

  final StreamController<double> _pitchController =
      StreamController<double>.broadcast();

  Stream<double> get pitchStream => _pitchController.stream;

  double _lastPitch = 0;
  double _smoothedPitch = 0;

  final double _smoothingFactor = 0.12; 
  DateTime _lastEmitTime = DateTime.now();

  PitchService() {
    _event.receiveBroadcastStream().listen(
      (event) {
        if (event is! double) return;
        if (event <= 0) return; 

        final hz = event;

        if ((hz - _lastPitch).abs() < 1) return;
        _lastPitch = hz;

        _smoothedPitch =
            _smoothedPitch +
                _smoothingFactor * (hz - _smoothedPitch);

        if (DateTime.now()
                .difference(_lastEmitTime)
                .inMilliseconds <
            40) {
          return;
        }

        _lastEmitTime = DateTime.now();

        _pitchController.add(_smoothedPitch);
      },
      onError: (_) {},
    );
  }

  void dispose() {
    _pitchController.close();
  }
}
