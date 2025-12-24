import 'package:flutter/material.dart';
import '../services/vehicle_check_service.dart';

class VehicleCheckScreen extends StatefulWidget {
  const VehicleCheckScreen({super.key});

  @override
  State<VehicleCheckScreen> createState() => _VehicleCheckScreenState();
}

class _VehicleCheckScreenState extends State<VehicleCheckScreen> {
  final _vehicleCheckService = VehicleCheckService();
  final _commentsController = TextEditingController();
  bool _isLoading = false;

  String? _tyres;
  String? _hazardLights;
  String? _brakeLights;
  String? _bodyCondition;
  String? _engineOil;
  String? _dashboardLights;

  final Map<String, List<Map<String, String>>> _options = {
    'tyres': [
      {'value': 'good', 'label': 'Good'},
      {'value': 'fair', 'label': 'Fair'},
      {'value': 'poor', 'label': 'Poor'},
      {'value': 'needs_replacement', 'label': 'Needs Replacement'},
    ],
    'hazardLights': [
      {'value': 'working', 'label': 'Working'},
      {'value': 'not_working', 'label': 'Not Working'},
      {'value': 'partial', 'label': 'Partial'},
    ],
    'brakeLights': [
      {'value': 'working', 'label': 'Working'},
      {'value': 'not_working', 'label': 'Not Working'},
      {'value': 'partial', 'label': 'Partial'},
    ],
    'bodyCondition': [
      {'value': 'excellent', 'label': 'Excellent'},
      {'value': 'good', 'label': 'Good'},
      {'value': 'fair', 'label': 'Fair'},
      {'value': 'poor', 'label': 'Poor'},
      {'value': 'damaged', 'label': 'Damaged'},
    ],
    'engineOil': [
      {'value': 'good', 'label': 'Good'},
      {'value': 'low', 'label': 'Low'},
      {'value': 'needs_change', 'label': 'Needs Change'},
      {'value': 'critical', 'label': 'Critical'},
    ],
    'dashboardLights': [
      {'value': 'none', 'label': 'None'},
      {'value': 'warning', 'label': 'Warning'},
      {'value': 'error', 'label': 'Error'},
      {'value': 'multiple', 'label': 'Multiple'},
    ],
  };

  void _submitVehicleCheck() async {
    if (_tyres == null ||
        _hazardLights == null ||
        _brakeLights == null ||
        _bodyCondition == null ||
        _engineOil == null ||
        _dashboardLights == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all vehicle check fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _vehicleCheckService.submitVehicleCheck(
      tyres: _tyres!,
      hazardLights: _hazardLights!,
      brakeLights: _brakeLights!,
      bodyCondition: _bodyCondition!,
      engineOil: _engineOil!,
      dashboardLights: _dashboardLights!,
      comments: _commentsController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit vehicle check'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDropdown(String field, String label, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _getFieldValue(field),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _options[field]!.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(option['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _setFieldValue(field, value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _getFieldValue(String field) {
    switch (field) {
      case 'tyres':
        return _tyres;
      case 'hazardLights':
        return _hazardLights;
      case 'brakeLights':
        return _brakeLights;
      case 'bodyCondition':
        return _bodyCondition;
      case 'engineOil':
        return _engineOil;
      case 'dashboardLights':
        return _dashboardLights;
      default:
        return null;
    }
  }

  void _setFieldValue(String field, String? value) {
    switch (field) {
      case 'tyres':
        _tyres = value;
        break;
      case 'hazardLights':
        _hazardLights = value;
        break;
      case 'brakeLights':
        _brakeLights = value;
        break;
      case 'bodyCondition':
        _bodyCondition = value;
        break;
      case 'engineOil':
        _engineOil = value;
        break;
      case 'dashboardLights':
        _dashboardLights = value;
        break;
    }
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Check'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.blue[50],
              child: Column(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 64,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pre-Shift Vehicle Check',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please complete the vehicle check before starting your shift',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            _buildDropdown('tyres', 'Tyres', Icons.tire_repair),
            _buildDropdown('hazardLights', 'Hazard Lights', Icons.warning_amber),
            _buildDropdown('brakeLights', 'Brake Lights', Icons.stop_circle),
            _buildDropdown('bodyCondition', 'Body Condition', Icons.car_repair),
            _buildDropdown('engineOil', 'Engine Oil', Icons.oil_barrel),
            _buildDropdown('dashboardLights', 'Dashboard Lights', Icons.dashboard),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Add any additional comments or notes...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitVehicleCheck,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Complete Vehicle Check',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

