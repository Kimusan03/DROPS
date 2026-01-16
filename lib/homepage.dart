import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ground_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String weatherApiKey = '7664af7d0ed6dbd1ad3d66d6421ebccb';
  final String city = 'Quezon City,PH';

  String temperature = '--';
  String rainStatus = '--';

  String dropsApiUrl = 'http://192.168.0.111:5000/water'; 
  bool _isActive = true;

  double? currentSensorDistance; 
  double? groundCalibration;
  
  // --- NEW: Water Sensor Variables ---
  double? waterSensorRaw; 
  String rainIntensity = "Dry";

  String flooding = 'NO';
  String raining = 'NO';
  String lastUpdated = 'Waiting...';

  Timer? weatherTimer;
  static const String _groundKey = 'ground_level_cm';
  static const String _ipKey = 'server_ip_address';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    fetchWeather();
    _scheduleNextPoll();

    weatherTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => fetchWeather(),
    );
  }

  @override
  void dispose() {
    _isActive = false; 
    weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString(_ipKey);
    final savedGround = prefs.getDouble(_groundKey);
    
    if (!mounted) return;
    setState(() {
      if (savedIp != null) dropsApiUrl = 'http://$savedIp:5000/water';
      groundCalibration = savedGround;
    });
  }

  void _showIpSettings() {
    final TextEditingController ipController = TextEditingController(
      text: dropsApiUrl.replaceAll('http://', '').replaceAll(':5000/water', '')
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Settings'),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(
            labelText: 'Server IP Address',
            hintText: 'e.g. 192.168.0.111',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newIp = ipController.text.trim();
              if (newIp.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_ipKey, newIp);
                setState(() {
                  dropsApiUrl = 'http://$newIp:5000/water';
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> fetchWeather() async {
    try {
      final url = 'https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&appid=$weatherApiKey';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          temperature = '${data['main']['temp']} °C';
          rainStatus = data['weather'][0]['main'];
        });
      }
    } catch (e) { debugPrint("Weather Error: $e"); }
  }

  void _scheduleNextPoll() async {
    if (!_isActive) return;
    await _fetchWaterData();
    if (!_isActive) return;
    Future.delayed(const Duration(milliseconds: 800), _scheduleNextPoll);
  }

  Future<void> _fetchWaterData() async {
    try {
      final res = await http.get(Uri.parse(dropsApiUrl)).timeout(const Duration(seconds: 2));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final rawDist = (data['distance_cm'] as num?)?.toDouble();
      // --- FETCH WATER SENSOR RAW DATA ---
      final rawWater = (data['water_level_cm'] as num?)?.toDouble();
      
      if (rawDist == null) return;
      if (!mounted) return;

      setState(() {
        currentSensorDistance = rawDist;
        waterSensorRaw = rawWater;

        // --- RAIN DETECTION LOGIC ---
        if (waterSensorRaw != null) {
          if (waterSensorRaw! > 400) {
            raining = 'YES';
            rainIntensity = "Heavy Rain";
          } else if (waterSensorRaw! > 30) {
            raining = 'YES';
            rainIntensity = "Light Rain";
          } else {
            raining = 'NO';
            rainIntensity = "Dry";
          }
        }

        final now = DateTime.now();
        lastUpdated = "${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

        if (groundCalibration != null) {
          final waterDepth = groundCalibration! - currentSensorDistance!;
          // Flooding threshold (adjust as needed)
          flooding = waterDepth >= 3.0 ? 'YES' : 'NO';
        }
      });
    } catch (e) { debugPrint("Poll Error: $e"); }
  }

  Future<void> openGroundConfig() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroundConfig(apiUrl: dropsApiUrl)),
    );
    if (selected is double) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_groundKey, selected);
      setState(() => groundCalibration = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    String depthDisplay = "--";
    if (groundCalibration != null && currentSensorDistance != null) {
       final val = groundCalibration! - currentSensorDistance!;
       depthDisplay = val < 0 ? "0.00" : val.toStringAsFixed(2);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DROPS Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showIpSettings),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: infoCard('Temp', temperature, Icons.thermostat)),
                  const SizedBox(width: 10),
                  Expanded(child: infoCard('Weather', rainStatus, Icons.cloud)),
                ],
              ),
              const SizedBox(height: 20),
              
              // --- SIDE-BY-SIDE STATUS BOXES ---
              Row(
                children: [
                  Expanded(child: statusBox('Flooding', flooding, (flooding == 'YES') ? Colors.red.shade400 : Colors.green.shade400)),
                  const SizedBox(width: 10),
                  Expanded(child: statusBox('Raining', raining, (raining == 'YES') ? Colors.blue.shade400 : Colors.grey.shade400)),
                ],
              ),
              
              const SizedBox(height: 12),

              // --- NEW: RAIN DETAIL CARD ---
              if (waterSensorRaw != null)
                Card(
                  elevation: 0,
                  color: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.umbrella, color: (raining == 'YES') ? Colors.blue : Colors.grey),
                    title: const Text('Rain Intensity', style: TextStyle(fontSize: 14)),
                    subtitle: Text(rainIntensity, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    trailing: Text('Raw: ${waterSensorRaw!.toInt()}', style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    const Text('Real-time Water Depth', style: TextStyle(color: Colors.blueGrey)),
                    Text('$depthDisplay cm', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 5),
                    Text('Updated: $lastUpdated', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_overscan),
                label: Text(groundCalibration == null ? 'Calibrate Sensor' : 'Recalibrate Sensor'),
                onPressed: openGroundConfig,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoCard(String title, String value, IconData icon) {
    return Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [Icon(icon, color: Colors.orange), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 12)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])));
  }

  Widget statusBox(String label, String value, Color color) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)), Text(value, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold))]));
  }
}