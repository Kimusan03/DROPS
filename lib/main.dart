import 'package:flutter/material.dart';
import 'homepage.dart'; // Import the robust file we just fixed

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DROPS Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Make the UI look a bit more modern
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black, // Dark text on white app bar
          elevation: 1,
        ),
      ),
      // Here is the key fix: Point to HomePage, not the old Dashboard
      home: const HomePage(),
    );
  }
}