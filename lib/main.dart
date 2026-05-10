import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jaksky_app/providers/prediction_provider.dart';
import 'package:jaksky_app/views/home/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PredictionProvider()..init(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'JakSky',
        theme: ThemeData(fontFamily: 'Inter'),
        home: HomeScreen(),
      ),
    );
  }
}
