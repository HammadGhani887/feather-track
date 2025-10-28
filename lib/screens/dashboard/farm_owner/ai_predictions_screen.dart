import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AiPredictionsScreen extends StatefulWidget {
  const AiPredictionsScreen({Key? key}) : super(key: key);

  @override
  _AiPredictionsScreenState createState() => _AiPredictionsScreenState();
}

enum TimePeriod { day, week, month, year }

class _AiPredictionsScreenState extends State<AiPredictionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedConsumptionController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _humidityController = TextEditingController();
  final _feedCostController = TextEditingController();
  final _hensController = TextEditingController();

  bool _isLoading = false;
  double? _predictedEggs;
  Map<String, dynamic>? _predictionDetails;
  bool _showAdvanced = false;
  TimePeriod _selectedPeriod = TimePeriod.day;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _predictionResults = [];

  // API Configuration
  static const String baseUrl = 'http://localhost:8001'; // For web and local development
  // For physical device testing, replace with your computer's IP address
  // static const String baseUrl = 'http://YOUR_COMPUTER_IP:8001';

  // Get day of year (1-366)
  int _getDayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  int _getIterationsForPeriod(TimePeriod period) {
    switch (period) {
      case TimePeriod.day:
        return 24; // Hourly predictions for a day
      case TimePeriod.week:
        return 7;  // Daily predictions for a week
      case TimePeriod.month:
        return 30; // Daily predictions for a month
      case TimePeriod.year:
        return 12; // Monthly predictions for a year
    }
  }

  DateTime _getDateForIteration(DateTime baseDate, int index) {
    switch (_selectedPeriod) {
      case TimePeriod.day:
        return baseDate.add(Duration(hours: index));
      case TimePeriod.week:
        return baseDate.add(Duration(days: index));
      case TimePeriod.month:
        return baseDate.add(Duration(days: index));
      case TimePeriod.year:
        return DateTime(baseDate.year + index ~/ 12, (baseDate.month + index - 1) % 12 + 1, 1);
    }
    // Add a default return statement to satisfy the analyzer
    return baseDate.add(Duration(days: index));
  }

  Future<void> _predictEggs() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _predictedEggs = null;
      _predictionDetails = null;
      _predictionResults = [];
    });

    try {
      final now = _selectedDate ?? DateTime.now();
      final int iterations = _getIterationsForPeriod(_selectedPeriod);
      final List<Future<http.Response>> requests = [];

      for (int i = 0; i < iterations; i++) {
        final currentDate = _getDateForIteration(now, i);
        requests.add(
          http.post(
            Uri.parse('$baseUrl/predict'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, dynamic>{
              'hour': currentDate.hour,
              'feed_consumption': double.tryParse(_feedConsumptionController.text) ?? 0.0,
              'temperature': double.tryParse(_temperatureController.text) ?? 0.0,
              'humidity': double.tryParse(_humidityController.text) ?? 0.0,
              'hens': int.tryParse(_hensController.text) ?? 0,
              'day_of_year': _getDayOfYear(currentDate),
              'month': currentDate.month,
              'day_of_week': currentDate.weekday,
            }),
          ),
        );
      }

      final responses = await Future.wait(requests);
      final List<Map<String, dynamic>> results = [];
      
      for (var response in responses) {
        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          // Handle both numeric and string prediction values
          final prediction = data['prediction'];
          final predictionValue = prediction is num 
              ? prediction.toDouble() 
              : double.tryParse(prediction.toString()) ?? 0.0;
              
          // Ensure we have all required fields with defaults
          results.add({
            'prediction': predictionValue,
            'features': {
              'feed_consumption': data['features']?['feed_consumption']?.toString() ?? _feedConsumptionController.text,
              'temperature': data['features']?['temperature']?.toString() ?? _temperatureController.text,
              'humidity': data['features']?['humidity']?.toString() ?? _humidityController.text,
              'hens': data['features']?['hens']?.toString() ?? _hensController.text,
            },
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else {
          throw Exception(data['detail']?.toString() ?? 'Failed to get prediction');
        }
      }

      if (mounted) {
        setState(() {
          _predictionResults = results;
          if (results.isNotEmpty) {
            _predictedEggs = results.last['prediction'] as double;
            _predictionDetails = results.last['features'] as Map<String, dynamic>;
          }
        });
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
        title: const Text('AI Egg Production Prediction'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Selection
              _buildPeriodSelector(),

              // Basic Input Fields
              _buildInputSection(
                title: 'Farm Conditions',
                children: [
                  _buildInputField(
                    'Number of Hens',
                    _hensController,
                    TextInputType.number,
                    (value) => value?.isEmpty ?? true ? 'Required' : null,
                    icon: Icons.egg_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    'Feed Consumption (kg)',
                    _feedConsumptionController,
                    TextInputType.number,
                    (value) => value?.isEmpty ?? true ? 'Required' : null,
                    icon: Icons.kitchen,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          'Temperature (°C)',
                          _temperatureController,
                          TextInputType.number,
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                          icon: Icons.thermostat,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          'Humidity (%)',
                          _humidityController,
                          TextInputType.number,
                          (value) => value?.isEmpty ?? true ? 'Required' : null,
                          icon: Icons.water_drop,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Advanced Options Toggle
              InkWell(
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAdvanced ? 'Hide Advanced' : 'Show Advanced',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ),
              ),

              // Advanced Options
              if (_showAdvanced)
                _buildInputSection(
                  title: 'Advanced Settings',
                  children: [
                    _buildInputField(
                      'Feed Cost (PKR)',
                      _feedCostController,
                      TextInputType.number,
                      (value) => null,
                      icon: Icons.attach_money,
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // Predict Button
              ElevatedButton(
                onPressed: _isLoading ? null : _predictEggs,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    : const Text(
                        'PREDICT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),

              // Prediction Results
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_predictionResults.isNotEmpty)
                ..._buildPredictionResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediction Period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPeriodChip(TimePeriod.day, 'Day'),
                _buildPeriodChip(TimePeriod.week, 'Week'),
                _buildPeriodChip(TimePeriod.month, 'Month'),
                _buildPeriodChip(TimePeriod.year, 'Year'),
              ],
            ),
            if (_selectedPeriod != TimePeriod.day)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Text('Start Date: '),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      child: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : DateFormat('MMM d, yyyy').format(_selectedDate!),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(TimePeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedPeriod = period;
            _predictionResults = [];
            _predictedEggs = null;
          }
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundColor: Colors.blue[200],
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _predictionResults = [];
        _predictedEggs = null;
      });
    }
  }

  List<Widget> _buildPredictionResults() {
    if (_predictionResults.isEmpty) return [];

    if (_predictionResults.length == 1) {
      return _buildSinglePrediction();
    }

    // For multiple predictions
    final totalEggs = _predictionResults.fold<double>(
      0,
      (sum, result) => sum + (result['prediction'] is int 
          ? result['prediction'].toDouble() 
          : result['prediction']),
    );
    
    final averageEggs = totalEggs / _predictionResults.length;
    
    return [
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prediction Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildSummaryRow('Time Period', _selectedPeriod.toString().split('.').last),
              _buildSummaryRow('Total Eggs', totalEggs.toStringAsFixed(0)),
              _buildSummaryRow('Average Daily', averageEggs.toStringAsFixed(1)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildPredictionChart(),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildPredictionChart() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _predictionResults.length,
      itemBuilder: (context, index) {
        final result = _predictionResults[index];
        final value = result['prediction'] is int 
            ? result['prediction'].toDouble() 
            : result['prediction'];
            
        return Container(
          width: 30,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: (value / (_predictionResults.fold(0.0, (max, e) => 
                  e['prediction'] > max ? e['prediction'] : max)) * 100),
                color: Colors.blue, // Changed to blue
              ),
              const SizedBox(height: 4),
              Text(
                '${value.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSinglePrediction() {
    return [
      Card(
        margin: const EdgeInsets.only(top: 24, bottom: 24),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text(
                'Predicted Egg Production',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.egg, size: 40, color: Colors.orange),
                  const SizedBox(width: 16),
                  Text(
                    '${_predictedEggs?.toStringAsFixed(1) ?? '0.0'} eggs',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_predictionDetails != null) ...[
                _buildDetailRow('Feed Consumption', '${_predictionDetails!['feed_consumption']} kg'),
                const Divider(),
                _buildDetailRow('Temperature', '${_predictionDetails!['temperature']}°C'),
                const Divider(),
                _buildDetailRow('Humidity', '${_predictionDetails!['humidity']}%'),
                const Divider(),
                _buildDetailRow('Number of Hens', _predictionDetails!['hens'].toString()),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildInputSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType,
    String? Function(String?)? validator, {
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  List<Widget> _buildPredictionResult() {
    return [
      const SizedBox(height: 24),
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Icon(
                Icons.egg,
                size: 48,
                color: Colors.amber,
              ),
              const SizedBox(height: 16),
              const Text(
                'Predicted Egg Production',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_predictedEggs?.toStringAsFixed(0) ?? '0'} eggs',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              if (_predictionDetails != null) ...[
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Prediction Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ..._predictionDetails!.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${e.key}:' ,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            e.value.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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

  @override
  void dispose() {
    _feedConsumptionController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    _feedCostController.dispose();
    _hensController.dispose();
    super.dispose();
  }
}
