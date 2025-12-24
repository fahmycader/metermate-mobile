import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/settings_service.dart';
import '../services/config_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _fontSize = 14.0;
  String _themeMode = 'light';
  String _backendUrl = '';
  bool _isLoading = true;
  bool _isTestingConnection = false;
  String? _connectionTestResult;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final fontSize = await SettingsService.getFontSize();
    final themeMode = await SettingsService.getThemeMode();
    final currentUrl = await ConfigService.getBaseUrl();
    setState(() {
      _fontSize = fontSize;
      _themeMode = themeMode;
      _backendUrl = currentUrl;
      _urlController.text = currentUrl;
      _isLoading = false;
    });
  }

  Future<void> _saveFontSize(double value) async {
    setState(() {
      _fontSize = value;
    });
    await SettingsService.setFontSize(value);
  }

  Future<void> _saveThemeMode(String value) async {
    setState(() {
      _themeMode = value;
    });
    await SettingsService.setThemeMode(value);
    // Notify parent to rebuild with new theme
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Theme changed. Restart app to see changes.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetSettings() async {
      final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: Text('Are you sure you want to reset all settings to default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SettingsService.resetSettings();
      await ConfigService.setCustomBaseUrl(null);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to default'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });

    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final healthUrl = '$baseUrl/health';
      
      print('🔍 Testing connection to: $healthUrl');
      
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dbStatus = data['database'] ?? 'unknown';
        final dbName = data['databaseName'] ?? 'unknown';
        final backendInfo = data['backend'] ?? {};
        
        setState(() {
          _connectionTestResult = '✅ Connection Successful!\n\n'
              'Backend: ${backendInfo['baseUrl'] ?? baseUrl}\n'
              'Database: $dbStatus\n'
              'Database Name: $dbName\n'
              'Status: ${data['status'] ?? 'ok'}';
        });
      } else {
        setState(() {
          _connectionTestResult = '❌ Connection Failed\n\n'
              'Status Code: ${response.statusCode}\n'
              'Backend responded but with an error.';
        });
      }
    } catch (e) {
      final baseUrl = await ConfigService.getBaseUrl();
      String errorMsg = '❌ Connection Failed\n\n';
      
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMsg += 'Connection timeout.\n\n'
            'Unable to reach backend at:\n$baseUrl\n\n'
            'Please check:\n'
            '1. Backend server is running\n'
            '2. Device is on the same network\n'
            '3. Firewall is not blocking the connection';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMsg += 'Cannot resolve host.\n\n'
            'Unable to reach:\n$baseUrl\n\n'
            'Please check:\n'
            '1. Backend server is running\n'
            '2. IP address is correct\n'
            '3. Device is on the same network';
      } else if (e.toString().contains('Connection refused')) {
        errorMsg += 'Connection refused.\n\n'
            'Backend at $baseUrl is not accepting connections.\n\n'
            'Please check:\n'
            '1. Backend server is running\n'
            '2. Port 3001 is not blocked';
      } else {
        errorMsg += 'Error: ${e.toString()}';
      }
      
      setState(() {
        _connectionTestResult = errorMsg;
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Font Size Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'Font Size',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current: ${_fontSize.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _fontSize,
                    min: 12.0,
                    max: 24.0,
                    divisions: 12,
                    label: _fontSize.toStringAsFixed(0),
                    onChanged: _saveFontSize,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Small', style: TextStyle(fontSize: 12)),
                      Text('Large', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Theme Mode Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'Theme Mode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Light Mode'),
                    subtitle: const Text('Default light theme'),
                    value: 'light',
                    groupValue: _themeMode,
                    onChanged: (value) => _saveThemeMode(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Dark theme for low light'),
                    value: 'dark',
                    groupValue: _themeMode,
                    onChanged: (value) => _saveThemeMode(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('System Default'),
                    subtitle: const Text('Follow device theme'),
                    value: 'system',
                    groupValue: _themeMode,
                    onChanged: (value) => _saveThemeMode(value!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Backend URL Configuration Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'Backend Server URL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure the backend server URL for mobile data access. Leave empty to use auto-detection.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Backend URL',
                      hintText: 'http://192.168.1.99:3001 (include :3001)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _urlController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _urlController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (value) {
                      setState(() {
                        _backendUrl = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Connection Test Result
                  if (_connectionTestResult != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _connectionTestResult!.contains('✅') 
                            ? Colors.green[50] 
                            : Colors.red[50],
                        border: Border.all(
                          color: _connectionTestResult!.contains('✅') 
                              ? Colors.green 
                              : Colors.red,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _connectionTestResult!,
                        style: TextStyle(
                          color: _connectionTestResult!.contains('✅') 
                              ? Colors.green[900] 
                              : Colors.red[900],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isTestingConnection ? null : _testConnection,
                        icon: _isTestingConnection 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find, size: 18),
                        label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _urlController.text = ConfigService.baseUrl;
                          setState(() {
                            _backendUrl = ConfigService.baseUrl;
                          });
                        },
                        child: const Text('Use Default'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          var url = _urlController.text.trim();
                          if (url.isNotEmpty) {
                            // Validate URL format
                            if (!url.startsWith('http://') && !url.startsWith('https://')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('URL must start with http:// or https://'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            // Auto-add port 3001 if missing and it's an IP address
                            final uri = Uri.tryParse(url);
                            if (uri != null) {
                              // Check if it's an IP address (not a domain)
                              final host = uri.host;
                              final isIpAddress = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(host);
                              
                              // If IP address and no port specified, add :3001
                              if (isIpAddress && uri.port == 0 && !url.contains(':')) {
                                url = '${url.replaceFirst(RegExp(r'/$'), '')}:3001';
                                _urlController.text = url;
                              }
                            }
                            
                            await ConfigService.setCustomBaseUrl(url);
                            setState(() {
                              _backendUrl = url;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Backend URL saved: $url\nRestart app to apply changes.'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } else {
                            // Clear custom URL
                            await ConfigService.setCustomBaseUrl(null);
                            final defaultUrl = await ConfigService.getBaseUrl();
                            setState(() {
                              _backendUrl = defaultUrl;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Using auto-detection. Restart app to apply.'),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save URL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Reset Button
          Card(
            child: ListTile(
              leading: Icon(Icons.restore, color: Colors.orange[700]),
              title: const Text('Reset to Defaults'),
              subtitle: const Text('Reset all settings to default values'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _resetSettings,
            ),
          ),
        ],
      ),
    );
  }
}

