import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AiPredictionsScreen extends StatefulWidget {
  const AiPredictionsScreen({Key? key}) : super(key: key);

  @override
  _AiPredictionsScreenState createState() => _AiPredictionsScreenState();
}

class _AiPredictionsScreenState extends State<AiPredictionsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  double? _predictedEggs;
  Map<String, dynamic>? _predictionDetails;
  
  // Controllers
  final TextEditingController _hourController = TextEditingController(
    text: DateTime.now().hour.toString(),
  );
  final TextEditingController _feedController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _hensController = TextEditingController();

  // API Configuration
  static const String baseUrl = 'http://localhost:8001'; // For web and local development
  // For physical device testing, replace with your computer's IP address
  // static const String baseUrl = 'http://YOUR_COMPUTER_IP:8001';

  @override
  void dispose() {
    _hourController.dispose();
    _feedController.dispose();
    _tempController.dispose();
    _humidityController.dispose();
    _hensController.dispose();
    super.dispose();
  }

  Future<void> _predictEggs() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _predictedEggs = null;
      _predictionDetails = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hour': int.parse(_hourController.text),
          'feed_consumption': double.parse(_feedController.text),
          'temperature': double.parse(_tempController.text),
          'humidity': double.parse(_humidityController.text),
          'hens': int.parse(_hensController.text),
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        setState(() {
          _predictedEggs = data['prediction'].toDouble();
          _predictionDetails = data['features'];
        });
      } else {
        throw Exception(data['detail'] ?? 'Failed to get prediction');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Egg Production Predictor'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputField(
                'Hour (0-23)',
                _hourController,
                TextInputType.number,
                (value) {
                  if (value == null || value.isEmpty) return 'Please enter hour';
                  final hour = int.tryParse(value);
                  if (hour == null || hour < 0 || hour > 23) {
                    return 'Enter a valid hour (0-23)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildInputField(
                'Feed Consumption (kg)',
                _feedController,
                TextInputType.number,
                (value) => value?.isEmpty ?? true ? 'Please enter feed consumption' : null,
              ),
              const SizedBox(height: 12),
              _buildInputField(
                'Temperature (°C)',
                _tempController,
                TextInputType.number,
                (value) => value?.isEmpty ?? true ? 'Please enter temperature' : null,
              ),
              const SizedBox(height: 12),
              _buildInputField(
                'Humidity (%)',
                _humidityController,
                TextInputType.number,
                (value) => value?.isEmpty ?? true ? 'Please enter humidity' : null,
              ),
              const SizedBox(height: 12),
              _buildInputField(
                'Number of Hens',
                _hensController,
                TextInputType.number,
                (value) => value?.isEmpty ?? true ? 'Please enter number of hens' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _predictEggs,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Predict Egg Production', style: TextStyle(fontSize: 16)),
              ),
              if (_predictedEggs != null) ..._buildPredictionResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType,
    String? Function(String?)? validator, {
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  List<Widget> _buildPredictionResult() {
    return [
      const SizedBox(height: 24),
      Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Predicted Egg Production',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '${_predictedEggs?.toStringAsFixed(0) ?? '0'} eggs',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 16),
              if (_predictionDetails != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Prediction Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._predictionDetails!.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${e.key}:',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(e.value.toString()),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}
