import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/meter_reading_service.dart';
import '../services/job_service.dart';
import '../services/location_service.dart';
import '../services/camera_service.dart';
import '../services/location_validation_service.dart';
import '../services/sync_service.dart';
import '../services/offline_storage_service.dart';
import '../widgets/location_input_dialog.dart';

class MeterReadingScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  
  const MeterReadingScreen({super.key, required this.job});

  @override
  State<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends State<MeterReadingScreen> {
  final MeterReadingService _meterReadingService = MeterReadingService();
  final LocationService _locationService = LocationService();
  final CameraService _cameraService = CameraService();
  
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, File?> _photos = {};
  
  String? _customerRead;
  String? _noAccessReason;
  
  // Valid no access reasons
  final List<String> _validNoAccessReasons = [
    'Property locked - no key access',
    'Dog on property - safety concern',
    'Occupant not home - appointment required',
    'Meter location inaccessible',
    'Property under construction',
    'Hazardous conditions present',
    'Permission denied by occupant',
    'Meter damaged - requires repair first',
  ];
  bool _isSubmitting = false;
  Position? _currentPosition;
  Map<String, dynamic>? _locationValidation;
  bool _isValidatingLocation = false;
  bool _risk = false;
  bool _mInspec = false;
  int _numRegisters = 1;

  final List<String> _customerReadOptions = [
    'First failed visit',
    'No access',
    'Refuse access by customer',
    'Incorrect address',
    'Vacent property',
    'Unable to read',
    'Unable to locate meter on site',
    'Faulty meter',
    'Meter blocked',
    'Unable to locate the meter',
    'Unmanned',
    'Demolished',
    'Unsafe premises',
  ];

  Timer? _locationCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _validateLocation();
    // Start continuous location tracking every 5 seconds
    _locationCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _validateLocation();
    });
  }

  Future<void> _validateLocation() async {
    // Don't show loading spinner on periodic updates
    if (!_isValidatingLocation) {
      setState(() => _isValidatingLocation = true);
    }
    
    try {
      // Get current position with retry and improved accuracy
      Position? position;
      int attempts = 0;
      double bestAccuracy = double.infinity;
      Position? bestPosition;
      
      while (attempts < 5 && (position == null || position.accuracy > 15.0)) {
        final currentPosition = await LocationValidationService.getCurrentPosition();
        if (currentPosition != null) {
          // Keep track of the most accurate position
          if (currentPosition.accuracy < bestAccuracy) {
            bestAccuracy = currentPosition.accuracy;
            bestPosition = currentPosition;
          }
          
          // If we have a good enough position (accuracy < 15m), use it
          if (currentPosition.accuracy <= 15.0) {
            position = currentPosition;
            break;
          }
          
          // Otherwise, wait and try again
          await Future.delayed(const Duration(milliseconds: 1000));
        } else {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
        attempts++;
      }
      
      // Use the best position we found, even if accuracy isn't perfect
      if (position == null && bestPosition != null) {
        position = bestPosition;
        print('⚠️ Using best available position with ${position.accuracy}m accuracy');
      }
      
      if (position == null) {
        setState(() {
          _locationValidation = {
            'isValid': false,
            'distance': 0.0,
            'error': 'Unable to get current location. Please enable location services.',
            'canProceed': false,
          };
          _isValidatingLocation = false;
        });
        return;
      }
      
      setState(() => _currentPosition = position);
      
      // Validate location
      final validation = await LocationValidationService.validateLocation(position, widget.job);
      setState(() => _locationValidation = validation);
      
    } catch (e) {
      print('Error validating location: $e');
      setState(() {
        _locationValidation = {
          'isValid': false,
          'distance': 0.0,
          'error': 'Error validating location: $e',
          'canProceed': false,
        };
      });
    } finally {
      setState(() => _isValidatingLocation = false);
    }
  }

  Future<void> _showManualLocationDialog() async {
    final addressString = LocationValidationService.buildAddressString(widget.job) ?? 'Unknown Address';
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LocationInputDialog(jobAddress: addressString),
    );
    
    if (result != null) {
      // Use manual coordinates for validation
      final position = _currentPosition;
      if (position != null) {
        final distance = LocationValidationService.calculateDistance(
          position.latitude,
          position.longitude,
          result['latitude'],
          result['longitude'],
        );
        
        final isValid = distance <= LocationValidationService.REQUIRED_RADIUS_METERS;
        
        setState(() {
          _locationValidation = {
            'isValid': isValid,
            'distance': distance,
            'jobCoordinates': result,
            'canProceed': isValid,
            'message': isValid 
                ? 'You are within the required ${LocationValidationService.REQUIRED_RADIUS_METERS}m radius'
                : 'You are ${distance.toStringAsFixed(0)}m away. Please move within ${LocationValidationService.REQUIRED_RADIUS_METERS}m to proceed.',
          };
        });
      }
    }
  }

  void _initializeControllers() {
    // Pre-fill from job data (read-only fields)
    final jobAddress = widget.job['address'] ?? {};
    final street = jobAddress['street'] ?? '';
    final city = jobAddress['city'] ?? '';
    final state = jobAddress['state'] ?? '';
    final zipCode = jobAddress['zipCode'] ?? '';
    final addressParts = [street, city, state, zipCode].where((part) => part.isNotEmpty).toList();
    final addressString = addressParts.join(', ');
    
    _controllers['sup'] = TextEditingController(text: widget.job['sup'] ?? '');
    _controllers['jt'] = TextEditingController(text: widget.job['jt'] ?? '');
    _controllers['cust'] = TextEditingController(text: widget.job['cust'] ?? '');
    _controllers['address1'] = TextEditingController(text: addressString);
    _controllers['address2'] = TextEditingController();
    _controllers['address3'] = TextEditingController();
    _controllers['noR'] = TextEditingController();
    _controllers['rc'] = TextEditingController();
    // Pre-fill meter information from job data (read-only)
    // Access meter fields from job data - these are set by admin when creating job
    final meterMake = widget.job['meterMake']?.toString().trim() ?? '';
    final meterModel = widget.job['meterModel']?.toString().trim() ?? '';
    final meterSerialNumber = widget.job['meterSerialNumber']?.toString().trim() ?? '';
    
    _controllers['makeOfMeter'] = TextEditingController(text: meterMake);
    _controllers['model'] = TextEditingController(text: meterModel);
    _controllers['meterSerialNumber'] = TextEditingController(text: meterSerialNumber);
    _controllers['regID1'] = TextEditingController();
    _controllers['reg1'] = TextEditingController();
    _controllers['notes'] = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Meter Reading'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _validateLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.work, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Job Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _viewJobLocation,
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('View Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Job ID', widget.job['_id']),
                      _buildInfoRow('Job Type', widget.job['jobType']?.toString().toUpperCase() ?? ''),
                      _buildInfoRow('Priority', widget.job['priority']?.toString().toUpperCase() ?? ''),
                      _buildInfoRow('Status', widget.job['status']?.toString().toUpperCase() ?? ''),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_isValidatingLocation)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              _locationValidation?['isValid'] == true ? Icons.check_circle : Icons.warning,
                              color: _locationValidation?['isValid'] == true ? Colors.green[700] : Colors.orange[700],
                            ),
                          const SizedBox(width: 8),
                          Text(
                            'Location Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _locationValidation?['isValid'] == true ? Colors.green[700] : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isValidatingLocation)
                        const Text('Validating location...')
                      else if (_locationValidation != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _locationValidation!['error'] ?? 'Distance to Job: ${_locationValidation!['distance'].toStringAsFixed(0)} meters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _locationValidation!['isValid'] == true ? Colors.green[600] : Colors.orange[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _locationValidation!['message'] ?? 'Location validation failed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _locationValidation!['isValid'] == true ? Colors.green[600] : Colors.orange[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _viewJobLocation,
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text('Google Maps'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _showManualLocationDialog,
                                  icon: const Icon(Icons.edit_location, size: 16),
                                  label: const Text('Manual'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else
                        const Text('Location validation not available'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Customer Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('Supplier (Sup)', 'sup', Icons.badge, readOnly: true),
                      const SizedBox(height: 12),
                      _buildTextField('Job Title (JT)', 'jt', Icons.work_outline, readOnly: true),
                      const SizedBox(height: 12),
                      _buildTextField('Customer (Cust)', 'cust', Icons.person_outline, readOnly: true),
                      const SizedBox(height: 12),
                      _buildTextField('Address', 'address1', Icons.location_on, readOnly: true),
                      const SizedBox(height: 12),
                      _buildTextField('Address 2', 'address2', Icons.location_city, required: false),
                      const SizedBox(height: 12),
                      _buildTextField('Address 3', 'address3', Icons.location_city, required: false),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Customer Read Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _customerRead,
                        decoration: const InputDecoration(
                          labelText: 'No Access Status?',
                          border: OutlineInputBorder(),
                          hintText: 'Select status',
                        ),
                        items: _customerReadOptions.map((String option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _customerRead = newValue;
                            // Reset no access reason if status changes
                            if (newValue != 'No access') {
                              _noAccessReason = null;
                            }
                          });
                        },
                        validator: null,
                      ),
                      // Show valid no access reason dropdown when "No access" is selected
                      if (_customerRead == 'No access') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _noAccessReason,
                          decoration: const InputDecoration(
                            labelText: 'No Access Reason *',
                            border: OutlineInputBorder(),
                            hintText: 'Select a valid reason',
                            helperText: 'Select a valid reason to receive 0.5 points',
                          ),
                          items: _validNoAccessReasons.map((String reason) {
                            return DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _noAccessReason = newValue;
                            });
                          },
                          validator: (value) {
                            if (_customerRead == 'No access' && (value == null || value.isEmpty)) {
                              return 'Please select a valid no access reason';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Risk?'),
                              value: _risk,
                              onChanged: (v) => setState(() => _risk = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('MInspec?'),
                              value: _mInspec,
                              onChanged: (v) => setState(() => _mInspec = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Meter Information Card - Always show meter info (pre-filled), but hide registers if no access
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed, color: Colors.purple[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Meter Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Meter Serial Number (pre-filled, read-only) - Display first for verification
                      _buildTextField('Meter Serial Number', 'meterSerialNumber', Icons.qr_code_scanner, readOnly: true),
                      const SizedBox(height: 12),
                      // Meter Make and Model (pre-filled, read-only)
                      _buildTextField('Make of Meter', 'makeOfMeter', Icons.build, readOnly: true),
                      const SizedBox(height: 12),
                      _buildTextField('Model', 'model', Icons.model_training, readOnly: true),
                      // Only show register fields if no access status is not selected
                      if (_customerRead == null) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _numRegisters,
                          decoration: const InputDecoration(
                            labelText: 'NoR (Number of Registers)',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(8, (i) => i + 1).map((n) => DropdownMenuItem<int>(
                            value: n,
                            child: Text(n.toString()),
                          )).toList(),
                          onChanged: (v) {
                            setState(() {
                              _numRegisters = v ?? 1;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        // Dynamic Register IDs and Values
                        ...List.generate(_numRegisters, (index) {
                          final idx = index + 1;
                          _controllers['regID$idx'] ??= TextEditingController();
                          _controllers['reg$idx'] ??= TextEditingController();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField('Reg ID$idx', 'regID$idx', Icons.confirmation_number, required: _mInspec),
                              const SizedBox(height: 8),
                              _buildTextField('Reg $idx', 'reg$idx', Icons.numbers, required: _mInspec),
                              const SizedBox(height: 12),
                            ],
                          );
                        }),
                      ] else ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Register fields are disabled when "No Access Status" is selected',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Photos Card - Always required, especially when no access status is selected
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.camera_alt, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Photos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          if (_customerRead != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Required',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_customerRead != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Photo is required when "No Access Status" is selected',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          if (_photos['meter'] != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _viewPhoto,
                                icon: const Icon(Icons.visibility),
                                label: const Text('View'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Notes Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, color: Colors.teal[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Additional Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _controllers['notes'],
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          hintText: 'Enter any additional notes...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || _locationValidation?['canProceed'] != true) ? null : _submitMeterReading,
                  icon: _isSubmitting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                  label: Text(_isSubmitting 
                      ? 'Submitting...' 
                      : _locationValidation?['canProceed'] != true
                          ? (_locationValidation?['error'] != null
                              ? 'Location Error - Use Manual Input'
                              : 'You are ${_locationValidation?['distance']?.toStringAsFixed(0) ?? '0'}m away. Please move within 10m to close the job.')
                          : _customerRead != null
                              ? 'Submit No Access Report'
                              : 'Submit Meter Reading'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _locationValidation?['canProceed'] == true 
                        ? Colors.green[700] 
                        : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String key, IconData icon, {bool required = true, bool readOnly = false, bool? enabled}) {
    // Determine if field should be required based on conditions:
    // - If readOnly, never required (pre-filled)
    // - If required parameter is false, never required
    // - If customerRead is selected (no access), not required
    // - If MInspec is checked, then required (only for register fields)
    final bool isRequired = !readOnly && required && _mInspec && _customerRead == null;
    final bool isEnabled = enabled ?? (!readOnly);
    
    return TextFormField(
      controller: _controllers[key],
      readOnly: readOnly || !isEnabled,
      enabled: isEnabled && !readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        filled: readOnly || !isEnabled,
        fillColor: (readOnly || !isEnabled) ? Colors.grey[200] : null,
        hintText: readOnly ? 'Pre-filled from job' : (!isEnabled ? 'Disabled when No Access Status is selected' : null),
      ),
      validator: isRequired ? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      } : null,
    );
  }

  Future<void> _takePhoto() async {
    try {
      File? photo = await _cameraService.takePhoto();
      if (photo != null) {
        setState(() {
          _photos['meter'] = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewPhoto() {
    if (_photos['meter'] != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Meter Photo'),
          content: Image.file(_photos['meter']!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _viewJobLocation() async {
    try {
      // Get job coordinates
      final jobCoords = await LocationValidationService.getJobCoordinates(widget.job);
      
      if (jobCoords == null) {
        // If no coordinates found, show manual input dialog
        await _showManualLocationDialog();
        return;
      }
      
      final lat = jobCoords['latitude'];
      final lng = jobCoords['longitude'];
      final addressString = LocationValidationService.buildAddressString(widget.job) ?? 'Job Location';
      
      // Create Google Maps URL
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
      
      // Check if we can launch URLs
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        // Show dialog to choose map app
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Open Job Location'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Job Address: $addressString'),
                    const SizedBox(height: 16),
                    const Text('Choose your preferred map app:'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Google Maps'),
                  ),
                  if (Platform.isIOS)
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Apple Maps'),
                    ),
                ],
              );
            },
          );
        }
      } else {
        // Fallback: show coordinates in a dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Job Location'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address: $addressString'),
                    const SizedBox(height: 8),
                    Text('Coordinates: $lat, $lng'),
                    const SizedBox(height: 16),
                    const Text(
                      'Copy these coordinates and paste them into your map app to navigate to the job location.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      print('Error opening job location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitMeterReading() async {
    // Always check location validation - must be within 10m of address location
    // This applies even when "No Access Status" is selected
    if (_locationValidation?['canProceed'] != true) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Validation Required'),
              content: Text(
                _locationValidation?['error'] != null
                    ? _locationValidation!['error']
                    : _locationValidation?['distance'] != null
                        ? 'You are ${_locationValidation!['distance'].toStringAsFixed(0)}m away from the job location. Please move within 10m to close the job.'
                        : 'You must be within 10 meters of the job location to complete this job.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    // If no access status is selected, only photo is required (location already validated above)
    if (_customerRead != null) {
      if (_photos['meter'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please take a photo when "No Access Status" is selected'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      // Normal validation for regular meter reading
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final syncService = SyncService();
    final isOnline = await syncService.isOnline();

    try {
      // Upload photo if taken (only if online)
      List<String> photoUrls = [];
      List<String> photoPaths = [];
      
      print('📸 Photo upload check: _photos=${_photos.keys.toList()}, hasMeterPhoto=${_photos['meter'] != null}');
      
      if (_photos['meter'] != null) {
        print('📸 Photo found, isOnline=$isOnline');
        if (isOnline) {
          // Upload photo immediately if online
          print('📤 Uploading photo to server...');
          String? url = await _cameraService.uploadPhoto(
            _photos['meter']!,
            widget.job['_id'],
            'meter',
          );
          if (url != null && url.isNotEmpty) {
            photoUrls.add(url);
            print('✅ Photo URL added to list: $url');
          } else {
            print('❌ Photo upload failed or returned null URL');
          }
        } else {
          // Save photo path for offline sync
          photoPaths.add(_photos['meter']!.path);
          print('💾 Saved photo path for offline sync: ${_photos['meter']!.path}');
        }
      } else {
        print('⚠️ No photo taken for this job');
      }
      
      print('📊 Final photo URLs count: ${photoUrls.length}, paths count: ${photoPaths.length}');

      // Prepare meter reading data
      Map<String, dynamic> readingData = {
        'jobId': widget.job['_id'],
        'sup': _controllers['sup']!.text,
        'jt': _controllers['jt']!.text,
        'cust': _controllers['cust']!.text,
        'address1': _controllers['address1']!.text,
        'address2': _controllers['address2']?.text, // Made optional
        'address3': _controllers['address3']?.text, // Made optional
        'customerRead': _customerRead, // Made optional
        'risk': _risk, // New field
        'mInspec': _mInspec, // New field
        'numRegisters': _numRegisters, // New field
        'makeOfMeter': _customerRead == null ? _controllers['makeOfMeter']!.text : '',
        'model': _customerRead == null ? _controllers['model']!.text : '',
        'meterSerialNumber': _customerRead == null ? _controllers['meterSerialNumber']!.text : '',
        'photos': photoUrls,
        'notes': _controllers['notes']?.text ?? '',
      };

      // Add location if available
      if (_currentPosition != null) {
        readingData['location'] = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        };
      }

      // Submit meter reading and complete the job
      final JobService jobService = JobService();
      
      // Prepare job completion data with location and distance
      // Build registers arrays
      final List<String> regIds = [];
      final List<num> regVals = [];
      for (int i = 1; i <= _numRegisters; i++) {
        final regId = _controllers['regID$i']?.text.trim();
        final regVal = _controllers['reg$i']?.text.trim();
        if (regId != null && regId.isNotEmpty) {
          regIds.add(regId);
        }
        if (regVal != null && regVal.isNotEmpty) {
          final val = num.tryParse(regVal);
          if (val != null) {
            regVals.add(val);
          }
        }
      }

      Map<String, dynamic> jobCompletionData = {
        'status': 'completed',
        'meterReadings': readingData,
        'photos': photoUrls,
        'location': _currentPosition != null ? {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        } : null,
        'notes': _controllers['notes']!.text,
        'risk': _risk,
        'mInspec': _mInspec,
        'numRegisters': _numRegisters,
        'registerIds': regIds,
        'registerValues': regVals,
      };
      
      // Add no access data if ANY "No Access Status" option is selected
      // Award 0.5 points for ANY no access status option
      if (_customerRead != null && _customerRead!.isNotEmpty) {
        jobCompletionData['customerRead'] = _customerRead;
        jobCompletionData['validNoAccess'] = true;
        // Use noAccessReason if provided (for "No access" option), otherwise use customerRead
        jobCompletionData['noAccessReason'] = _noAccessReason ?? _customerRead;
      }

      // Add distance calculation if we have location validation data
      if (_locationValidation?['jobCoordinates'] != null && _currentPosition != null) {
        final jobCoords = _locationValidation!['jobCoordinates'];
        final distance = _locationValidation!['distance'];
        
        jobCompletionData['distanceTraveled'] = distance / 1000; // Convert to kilometers
        jobCompletionData['endLocation'] = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Complete the job - online or offline
      if (isOnline) {
        // Submit immediately if online
        final result = await jobService.completeJob(widget.job['_id'], jobCompletionData);
        
        if (result['success']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Job completed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        } else {
          // If submission fails, save to offline storage
          await _saveOffline(photoPaths, jobCompletionData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${result['message']}. Saved offline for sync.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
            Navigator.of(context).pop(true);
          }
        }
      } else {
        // Save to offline storage if offline
        await _saveOffline(photoPaths, jobCompletionData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job saved offline. Will sync when connection is restored.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting meter reading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Save job completion to offline storage
  Future<void> _saveOffline(List<String> photoPaths, Map<String, dynamic> jobCompletionData) async {
    try {
      final storage = OfflineStorageService();
      await storage.savePendingJobCompletion(
        jobId: widget.job['_id'],
        completionData: jobCompletionData,
        photoPaths: photoPaths.isNotEmpty ? photoPaths : null,
      );
      print('💾 Saved job completion offline: ${widget.job['_id']}');
    } catch (e) {
      print('❌ Error saving offline: $e');
    }
  }

  @override
  void dispose() {
    _locationCheckTimer?.cancel();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
