import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const VoctaveApp());
}

class VoctaveApp extends StatelessWidget {
  const VoctaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}