import 'package:flutter/material.dart';

class AppSettings {

  // Selected Major note (C,D,E,F,G,A,B)
  static ValueNotifier<String> major = ValueNotifier<String>('C');

  // Pitch smoothing sensitivity
  static ValueNotifier<double> sensitivity = ValueNotifier<double>(0.18);

}