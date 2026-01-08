import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your project URL and anon key
  await Supabase.initialize(
    url: 'https://hndshgsyfqxplmtayfqe.supabase.co', // replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhuZHNoZ3N5ZnF4cGxtdGF5ZnFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc2MTI0ODYsImV4cCI6MjA4MzE4ODQ4Nn0.m2mU6MAxQTjf335jLKzfApoknsono6UyMZ0Q3KAiyxU',                    // replace with your anon key
  );

  runApp(const DropsApp());
}

class DropsApp extends StatelessWidget {
  const DropsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DROPS App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WeatherHome(),
    );
  }
} 
