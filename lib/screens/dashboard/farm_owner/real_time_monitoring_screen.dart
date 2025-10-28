import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class RealTimeMonitoringScreen extends StatefulWidget {
  const RealTimeMonitoringScreen({super.key});

  @override
  State<RealTimeMonitoringScreen> createState() => _RealTimeMonitoringScreenState();
}

class _RealTimeMonitoringScreenState extends State<RealTimeMonitoringScreen> {
  late DatabaseReference _sensorRef;
  late Stream<DatabaseEvent> _sensorDataStream;

  @override
  void initState() {
    super.initState();
    // Initialize the reference to sensor data
    _sensorRef = FirebaseDatabase.instance.ref().child('sensor');
    // Set up the stream
    _sensorDataStream = _sensorRef.onValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Real Time Monitoring',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _sensorDataStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

          if (data == null) {
            return const Center(
              child: Text(
                'No sensor data available',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Readings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSensorCard(
                  'Temperature',
                  data['temperature']?.toString() ?? 'N/A',
                  data['temperature_status']?.toString() ?? '',
                  Colors.orange,
                  Icons.thermostat,
                ),
                const SizedBox(height: 16),
                _buildSensorCard(
                  'Humidity',
                  data['humidity']?.toString() ?? 'N/A',
                  data['humidity_status']?.toString() ?? '',
                  Colors.blue,
                  Icons.water_drop,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSensorCard(
    String title,
    String value,
    String status,
    Color color,
    IconData icon,
  ) {
    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (status.isNotEmpty)
                  Text(
                    status,
                    style: TextStyle(
                      color: status.contains('⚠️') ? Colors.amber : Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}