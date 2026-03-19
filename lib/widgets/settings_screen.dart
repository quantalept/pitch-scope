import 'package:flutter/material.dart';
import '../utils/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  /// Full scale list
  final List<String> scales = const [

    "C Major",
    "C Minor",
    "C♭ Major",
    "C♯ Major",
    "C♯ Minor",

    "D Major",
    "D Minor",
    "D♭ Major",
    "D♯ Minor",

    "E Major",
    "E Minor",
    "E♭ Major",
    "E♭ Minor",

    "F Major",
    "F Minor",
    "F♯ Major",
    "F♯ Minor",

    "G Major",
    "G Minor",
    "G♭ Major",
    "G♯ Minor",

    "A Major",
    "A Minor",
    "A♭ Major",
    "A♭ Minor",

    "B Major",
    "B Minor",
    "B♭ Major",
    "B♭ Minor",

    "Chromatic",
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFF1A0026),

      appBar: AppBar(
        backgroundColor: const Color(0xFF12001D),
        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white),
        ),
      ),

      /// FIX 1 → Scrollable screen
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// SCALE TITLE
              const Text(
                "Scale",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 10),

              /// SCALE DROPDOWN
              ValueListenableBuilder<String>(
                valueListenable: AppSettings.major,
                builder: (context, value, _) {

                  /// FIX 2 → Safe dropdown value
                  String currentValue =
                      scales.contains(value) ? value : scales.first;

                  return DropdownButton<String>(

                    value: currentValue,
                    dropdownColor: const Color(0xFF1A0026),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,

                    items: scales.map((scale) {

                      return DropdownMenuItem(
                        value: scale,
                        child: Text(
                          scale,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      );

                    }).toList(),

                    onChanged: (newValue) {
                      if (newValue != null) {
                        /// FIX 3 → store full scale
                        AppSettings.major.value = newValue;
                      }
                    },
                  );
                },
              ),

              const SizedBox(height: 40),

              /// PITCH SENSITIVITY TITLE
              const Text(
                "Pitch Sensitivity",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 10),

              /// SENSITIVITY SLIDER
              ValueListenableBuilder<double>(
                valueListenable: AppSettings.sensitivity,
                builder: (context, value, _) {

                  return Slider(

                    value: value,
                    min: 0.05,
                    max: 0.5,

                    activeColor: Colors.purpleAccent,

                    onChanged: (newValue) {
                      AppSettings.sensitivity.value = newValue;
                    },
                  );
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}