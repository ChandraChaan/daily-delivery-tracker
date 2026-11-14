import 'package:flutter/material.dart';

import 'src/home_page.dart';

void main() => runApp(const DeliveryApp());

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key, this.home});

  /// For tests.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Delivery Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B6E8F), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B6E8F),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: home ?? const HomePage(),
    );
  }
}
