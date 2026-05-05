import 'package:flutter/material.dart';
import 'package:jaksky_app/views/home/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JakSky',
      theme: ThemeData(fontFamily: 'Inter'),
      home: HomeScreen(),
    );
  }
}
