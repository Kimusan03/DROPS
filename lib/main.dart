import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// ------------------- ROOT WIDGET -------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DROPS Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // ------------------- OpenWeather API Settings -------------------
  final String weatherApiKey = '7664af7d0ed6dbd1ad3d66d6421ebccb';  // <-- REPLACE
  final String city = 'Quezon City,PH';

  String temperature = '--';
  String rainStatus = '--';

  // ------------------- Local Python DROPS API -------------------
  final String dropsApiUrl = 'http://localhost:5000/water'; // replace with PC IP if needed
  double? waterLevel;
  String flooding = '--';
  String raining = '--';

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchWeather();
    fetchFloodData();

    // Auto-refresh every 10 seconds
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchWeather();
      fetchFloodData();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  // ------------------- Fetch Weather from OpenWeather -------------------
  Future<void> fetchWeather() async {
    try {
      final url =
          'https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&appid=$weatherApiKey';
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      setState(() {
        temperature = '${data['main']['temp']} °C';
        rainStatus = data['weather'][0]['main']; // Clear, Rain, Clouds, etc.
      });
    } catch (e) {
      setState(() {
        temperature = '--';
        rainStatus = '--';
      });
      print('Weather API error: $e');
    }
  }

  // ------------------- Fetch Flooding & Raining from Python API -------------------
  Future<void> fetchFloodData() async {
    try {
      final res = await http.get(Uri.parse(dropsApiUrl)).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final level = (data['water_level_cm'] as num?)?.toDouble() ?? 0.0;
        setState(() {
          waterLevel = level;
          // thresholds (adjust as needed)
          flooding = (level > 30) ? 'YES' : 'NO';
          raining = (level > 10) ? 'YES' : 'NO';
        });
      } else {
        setState(() {
          flooding = '--';
          raining = '--';
        });
      }
    } catch (e) {
      setState(() {
        flooding = '--';
        raining = '--';
      });
      print('Python API fetch error: $e');
    }
  }

  // ------------------- Color coding for flood -------------------
  Color floodColor() {
    if (flooding == 'YES') return Colors.red;
    if (flooding == 'NO') return Colors.green;
    return Colors.grey;
  }

  // ------------------- Color coding for rain -------------------
  Color rainColor() {
    if (raining == 'YES') return Colors.blue;
    if (raining == 'NO') return Colors.grey;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DROPS Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Temperature card
            infoCard('Temperature', temperature),

            // Rain forecast from OpenWeather
            infoCard('Rain Prediction', rainStatus),

            const SizedBox(height: 20),

            // Flooding alert from Arduino/Python API
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: floodColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Flooding: $flooding',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Raining alert based on water level
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: rainColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Raining: $raining',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Optional: show raw water level
            if (waterLevel != null)
              Text('Water Level: ${waterLevel!.toStringAsFixed(2)} cm',
                  style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  // ------------------- Helper function for small info cards -------------------
  Widget infoCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
