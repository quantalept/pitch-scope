import 'dart:async';
import 'package:flutter/services.dart';

class PitchService {
  static const EventChannel _event =
      EventChannel('pitchscope/event');

  final StreamController<double> _pitchController =
      StreamController<double>.broadcast();

  Stream<double> get pitchStream => _pitchController.stream;

  PitchService() {
    _event.receiveBroadcastStream().listen(
      (event) {
        if (event is double && event > 0) {
          _pitchController.add(event);
        }
      },
      onError: (e) {
        // ignore noisy frames
      },
    );
  }

  void dispose() {
    _pitchController.close();
  }
}
