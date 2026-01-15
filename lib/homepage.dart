import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ground_config.dart'; // make sure this points to your GroundConfig file

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ------------------- OpenWeather API Settings -------------------
  final String weatherApiKey = '7664af7d0ed6dbd1ad3d66d6421ebccb'; 
  final String city = 'Quezon City,PH'; 

  String temperature = '--';
  String rainStatus = '--';

  // ------------------- Local Python DROPS API -------------------
  final String dropsApiUrl = 'http://192.168.0.111:5000/water'; // your PC IP
  double? waterLevel;
  double? groundLevel; // set by GroundConfig
  String flooding = '--';
  String raining = '--';

  Timer? refreshTimer;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    fetchWeather();
    fetchFloodData();

    // Auto-refresh every 1 second for near real-time
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
        rainStatus = data['weather'][0]['main'];
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
    if (_fetching) return;
    _fetching = true;
    try {
      final res = await http.get(Uri.parse(dropsApiUrl)).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final level = (data['water_level_cm'] as num?)?.toDouble() ?? 0.0;

        setState(() {
          waterLevel = level;

          if (groundLevel != null) {
            final delta = waterLevel! - groundLevel!;
            flooding = (delta >= 3) ? 'YES' : 'NO'; // customize threshold
            raining = (waterLevel! > 0) ? 'YES' : 'NO';
          } else {
            flooding = '--';
            raining = '--';
          }
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
    } finally {
      _fetching = false;
    }
  }

  // ------------------- Color coding -------------------
  Color floodColor() {
    if (flooding == 'YES') return Colors.red;
    if (flooding == 'NO') return Colors.green;
    return Colors.grey;
  }

  Color rainColor() {
    if (raining == 'YES') return Colors.blue;
    if (raining == 'NO') return Colors.grey;
    return Colors.grey;
  }

  // ------------------- Navigate to GroundConfig -------------------
  Future<void> setGroundLevel() async {
    final selectedGround = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroundConfig(apiUrl: dropsApiUrl),
      ),
    );
    if (selectedGround != null && selectedGround is double) {
      setState(() {
        groundLevel = selectedGround;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ground set at ${groundLevel!.toStringAsFixed(2)} cm')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final delta = (groundLevel != null && waterLevel != null) ? waterLevel! - groundLevel! : null;

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

            // Flooding alert
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: floodColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Flooding: $flooding',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            // Raining alert
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: rainColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Raining: $raining',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            // Show raw water level
            if (waterLevel != null)
              Text('Water Level: ${waterLevel!.toStringAsFixed(2)} cm', style: const TextStyle(fontSize: 18)),

            if (delta != null)
              Text('Δ from Ground: ${delta.toStringAsFixed(2)} cm', style: const TextStyle(fontSize: 18)),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: setGroundLevel,
              child: const Text('Set Ground Level'),
            ),
          ],
        ),
      ),
    );
  }

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
