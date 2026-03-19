import 'package:flutter/material.dart';

class AppSettings {

  /// Selected Scale (used across app)
  /// Default must match dropdown values
  static final ValueNotifier<String> major =
      ValueNotifier<String>("C Major");

  /// Pitch smoothing sensitivity
  static final ValueNotifier<double> sensitivity =
      ValueNotifier<double>(0.18);

}