import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});

  @override
  _WeatherHomeState createState() => _WeatherHomeState();
}

class WeatherHomeState extends State<WeatherHome> {
  String weather = 'Loading...';
  double waterLevel = 0;
  bool rainDetected = false;

  final supabase = Supabase.instance.client;

  // Fetch weather from Open-Meteo
  Future<void> fetchWeather() async {

    const url =
     'https://api.open-meteo.com/v1/forecast'
      '?latitude=14.6760'
      '&longitude=121.0437'
      '&hourly=temperature_2m,precipitation,weathercode'
      '&forecast_days=1'
      '&timezone=Asia/Manila';


    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    setState(() {
      if (response.statusCode == 200 && data['current_weather'] != null) {
        double temp = data['current_weather']['temperature'];
        weather = 'Temperature: $temp°C';
      } else {
        weather = 'Error fetching weather';
      }
    });
  }

  // Fetch latest Arduino data from Supabase
Future<void> fetchArduinoData() async {
  final data = await supabase
      .from('arduino_data')
      .select()
      .order('timestamp', ascending: false)
      .limit(1);

  if (data.isNotEmpty) {
    final latest = data[0];
    setState(() {
      waterLevel = (latest['water_level'] ?? 0).toDouble();
      rainDetected = latest['rain_detected'] ?? false;
    });
  }
}


  // Combine both
  Future<void> refreshData() async {
    await fetchWeather();
    await fetchArduinoData();
  }

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DROPS Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weather, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 20),
            Text('Water Level: $waterLevel m', style: const TextStyle(fontSize: 24)),
            Text('Rain Detected: ${rainDetected ? "Yes" : "No"}', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: refreshData,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
