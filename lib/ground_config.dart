import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GroundConfig extends StatefulWidget {
  final String apiUrl;
  const GroundConfig({Key? key, required this.apiUrl}) : super(key: key);

  @override
  State<GroundConfig> createState() => _GroundConfigState();
}

class _GroundConfigState extends State<GroundConfig> {
  double? _currentRawDistance;
  Timer? _pollTimer;
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start polling immediately
    _fetchWaterLevel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 1000), // Slower polling (1s) to be safe
      (_) => _fetchWaterLevel(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWaterLevel() async {
    if (_fetching || !mounted) return;
    _fetching = true;

    try {
      // robust URL parsing
      final uri = Uri.tryParse(widget.apiUrl);
      if (uri == null || !uri.hasScheme) {
        throw const FormatException("Invalid URL format");
      }

      final resp = await http.get(uri).timeout(const Duration(seconds: 3));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        
        // We prioritize 'distance_cm' because that is the RAW sensor reading.
        // For calibration, we need the distance from Sensor -> Ground.
        final rawDist = data['distance_cm'];
        
        if (rawDist != null) {
          setState(() {
            _currentRawDistance = (rawDist as num).toDouble();
            _error = null;
          });
        } else {
           // Fallback if sensor is sending weird data
           setState(() => _error = "Sensor Data Missing");
        }
      } else {
        setState(() => _error = 'Server Error: ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Connection Error: Check IP');
      }
      debugPrint("API Error: $e");
    } finally {
      _fetching = false;
    }
  }

  void _confirmAndSet() {
    if (_currentRawDistance == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Calibration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Is the ground currently dry/empty?'),
            const SizedBox(height: 10),
            Text(
              'Setting Sensor Height to:\n${_currentRawDistance!.toStringAsFixed(1)} cm',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              'Future water levels will be calculated based on this depth.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, _currentRawDistance); // Return value to HomePage
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibrate Sensor')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Current Sensor Reading',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Big Display Container
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: _error != null ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _error != null ? Colors.red.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Column(
                children: [
                  if (_currentRawDistance == null && _error == null)
                    const CircularProgressIndicator()
                  else
                    Text(
                      _currentRawDistance != null
                          ? '${_currentRawDistance!.toStringAsFixed(1)} cm'
                          : '--',
                      style: TextStyle(
                        fontSize: 42, 
                        fontWeight: FontWeight.bold,
                        color: _error != null ? Colors.red : Colors.blue.shade800,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            
            const Spacer(),
            
            const Text(
              "Ensure the sensor is mounted in its final position before confirming.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.blue.shade700,
                   foregroundColor: Colors.white,
                ),
                onPressed: _currentRawDistance != null ? _confirmAndSet : null,
                child: const Text('SET AS ZERO LEVEL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}