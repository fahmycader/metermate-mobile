import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConfigService {
  static Map<String, dynamic>? _config;
  static String _environment = 'development';
  static String? _customBaseUrl;
  static final Connectivity _connectivity = Connectivity();

  static Future<void> initialize() async {
    try {
      final String configString = await rootBundle.loadString('assets/config/ipconfig.json');
      final Map<String, dynamic> config = json.decode(configString);
      _config = config;
    } catch (e) {
      print('Error loading config: $e');
      // Fallback to hardcoded values if config file is not found
      _config = {
        'development': {
          'backend': {
            'ip': '192.168.1.99',
            'port': 3001,
            'baseUrl': 'http://192.168.1.99:3001',
            'mobileDataUrl': 'http://192.168.1.99:3001' // Same as backend IP
          }
        }
      };
    }
    
    // Load custom URL from preferences if set
    final prefs = await SharedPreferences.getInstance();
    _customBaseUrl = prefs.getString('custom_backend_url');
  }

  // Set custom backend URL (for mobile data or different network)
  static Future<void> setCustomBaseUrl(String? url) async {
    _customBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    if (url != null) {
      await prefs.setString('custom_backend_url', url);
    } else {
      await prefs.remove('custom_backend_url');
    }
  }

  // Get the appropriate base URL based on connectivity
  static Future<String> _getBaseUrl() async {
    // If custom URL is set, use it
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    // Check connectivity type
    final results = await _connectivity.checkConnectivity();
    final isMobileData = results.contains(ConnectivityResult.mobile);
    final isWifi = results.contains(ConnectivityResult.wifi);

    // Get URLs from config
    final wifiUrl = _config?[_environment]?['backend']?['baseUrl'] ?? 'http://192.168.1.99:3001';
    final mobileDataUrl = _config?[_environment]?['backend']?['mobileDataUrl'] ?? wifiUrl;

    // For mobile app, always use IP address (not localhost)
    // Use mobile data URL if on mobile data, otherwise use WiFi URL (which should be IP address)
    if (isMobileData && !isWifi) {
      return mobileDataUrl;
    }
    
    // Always use IP address for mobile devices (not localhost)
    return wifiUrl;
  }

  static void setEnvironment(String environment) {
    _environment = environment;
  }

  static String get backendIp {
    return _config?[_environment]?['backend']?['ip'] ?? '192.168.1.99';
  }

  static int get backendPort {
    return _config?[_environment]?['backend']?['port'] ?? 3001;
  }

  static String get baseUrl {
    // This is a synchronous getter, but we need async for connectivity check
    // For now, return the configured URL. Use getBaseUrl() for dynamic URL.
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    return _config?[_environment]?['backend']?['baseUrl'] ?? 'http://192.168.1.99:3001';
  }

  // Async method to get base URL with connectivity check
  static Future<String> getBaseUrl() async {
    return await _getBaseUrl();
  }

  static String get apiUrl {
    return '$baseUrl/api';
  }

  static String get authUrl {
    return '$baseUrl/api/auth';
  }

  static String get jobsUrl {
    return '$baseUrl/api/jobs';
  }

  static String get messagesUrl {
    return '$baseUrl/api/messages';
  }

  static String get uploadUrl {
    return '$baseUrl/api/upload';
  }

  static String get housesUrl {
    return '$baseUrl/api/houses';
  }
}
