import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  // ------------------- OpenWeather API Settings -------------------
  final String weatherApiKey = '7664af7d0ed6dbd1ad3d66d6421ebccb'; // <-- REPLACE with your API key
  final String city = 'Quezon City,PH';                    // <-- You can change city

  String temperature = '--';
  String rainStatus = '--';

  // ------------------- Supabase Flood & Rain Data -------------------
  String flooding = '--';
  String raining = '--';

  // ------------------- Timer for auto-refresh -------------------
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchWeather();
    fetchFloodData();

    // ------------------- Auto-refresh every 10 seconds -------------------
    refreshTimer = Timer.periodic(Duration(seconds: 10), (timer) {
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

  // ------------------- Fetch Flooding & Raining from Supabase -------------------
  Future<void> fetchFloodData() async {
    try {
      final data = await supabase
          .from('flood_data')
          .select('flooding,raining')
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      setState(() {
        flooding = data['flooding'];
        raining = data['raining'];
      });
    } catch (e) {
      setState(() {
        flooding = '--';
        raining = '--';
      });
      print('Supabase fetch error: $e');
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

            // Flooding alert from Arduino/ESP-01
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

            // Raining alert from water level sensor
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
