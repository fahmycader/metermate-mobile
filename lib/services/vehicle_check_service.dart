import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class VehicleCheckService {
  static Future<String> get _baseUrl async => '${await ConfigService.getBaseUrl()}/api/vehicle-checks';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>> submitVehicleCheck({
    required String tyres,
    required String hazardLights,
    required String brakeLights,
    required String bodyCondition,
    required String engineOil,
    required String dashboardLights,
    String? comments,
  }) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse(await _baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'tyres': tyres,
          'hazardLights': hazardLights,
          'brakeLights': brakeLights,
          'bodyCondition': bodyCondition,
          'engineOil': engineOil,
          'dashboardLights': dashboardLights,
          'comments': comments ?? '',
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to submit vehicle check'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getVehicleChecks({String? operativeId}) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      String url = await _baseUrl;
      if (operativeId != null) {
        url = '$url/operative/$operativeId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'] ?? []};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get vehicle checks'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getTodaysVehicleCheck() async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('${await _baseUrl}/today'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get today\'s vehicle check'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }
}

