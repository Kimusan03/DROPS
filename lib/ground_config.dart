import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GroundConfig extends StatefulWidget {
  final String apiUrl;
  const GroundConfig({Key? key, required this.apiUrl}) : super(key: key);

  @override
  _GroundConfigState createState() => _GroundConfigState();
}

class _GroundConfigState extends State<GroundConfig> {
  double? _currentWaterLevel;
  Timer? _pollTimer;
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Poll every 500ms for live water level
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _fetchWaterLevel());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWaterLevel() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final resp = await http.get(Uri.parse(widget.apiUrl)).timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _currentWaterLevel = (data['water_level_cm'] as num?)?.toDouble();
          _error = null;
        });
      } else {
        setState(() {
          _error = 'API ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      _fetching = false;
    }
  }

  void _setGroundLevel() {
    if (_currentWaterLevel != null) {
      // Pop back and return the ground value
      Navigator.pop(context, _currentWaterLevel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ground Config")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Current water level: ${_currentWaterLevel?.toStringAsFixed(2) ?? '--'} cm",
              style: const TextStyle(fontSize: 24),
            ),
            if (_error != null)
              Text("Error: $_error", style: const TextStyle(color: Colors.red)),
            const Spacer(),
            ElevatedButton(
              onPressed: _setGroundLevel,
              child: const Text("Set Ground"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchWaterLevel,
              child: const Text("Refresh Now"),
            ),
          ],
        ),
      ),
    );
  }
}
