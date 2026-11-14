import 'package:flutter/material.dart';

import 'src/home_page.dart';
import 'src/look.dart';

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
      theme: Look.light.theme(Brightness.light),
      darkTheme: Look.dark.theme(Brightness.dark),
      home: home ?? const HomePage(),
    );
  }
}
