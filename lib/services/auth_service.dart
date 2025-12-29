import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class AuthService {
  // For physical device, use IP address instead of localhost

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      print('🔗 Attempting to connect to: $authUrl/login');
      final response = await http.post(
        Uri.parse('$authUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Save user data and token
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        await prefs.setString('userData', jsonEncode(responseData));
        await prefs.setBool('isLoggedIn', true);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Login failed'};
      }
    } catch (e) {
      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      print('❌ Login Error: $e');
      print('❌ Failed URL: $authUrl/login');
      print('❌ Error type: ${e.runtimeType}');
      String errorMessage = 'Could not connect to the server.';
      final currentBaseUrl = await ConfigService.getBaseUrl();
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        // Check if URL is missing port
        final uri = Uri.tryParse(currentBaseUrl);
        final hasPort = uri != null && uri.port != 0;
        final portHint = !hasPort ? '\n\n⚠️ Missing port number! URL should be: $currentBaseUrl:3001' : '';
        errorMessage = 'Connection timeout. Please check your network connection.\n\nCurrent URL: $currentBaseUrl$portHint\n\nIf on mobile data:\n1. Ensure port forwarding is configured on router\n2. Update Settings > Backend Server URL to: http://YOUR_PUBLIC_IP:3001';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Cannot reach server at $currentBaseUrl.\n\nPlease check:\n1. Backend server is running\n2. If on mobile data, set the correct backend URL in Settings\n3. Firewall is not blocking the connection';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Connection refused. Please ensure the backend server is running on $currentBaseUrl';
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> register(String username, String password, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? employeeId,
    String? department,
    String? verificationCode,
  }) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      final response = await http.post(
        Uri.parse('$authUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username, 
          'password': password,
          'firstName': firstName ?? '',
          'lastName': lastName ?? '',
          'email': email ?? '',
          'phone': phone ?? '',
          'employeeId': employeeId ?? '',
          'department': department ?? '',
          'verificationCode': verificationCode ?? '',
        }),
      );
      
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201) {
        // Save user data and token
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        await prefs.setString('userData', jsonEncode(responseData));
        await prefs.setBool('isLoggedIn', true);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      print('Register Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> sendVerificationCode(String email, {String type = 'registration'}) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      final response = await http.post(
        Uri.parse('$authUrl/send-verification-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'type': type}),
      );
      
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to send verification code'};
      }
    } catch (e) {
      print('Send Verification Code Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> verifyCode(String email, String code, {String type = 'registration'}) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      final response = await http.post(
        Uri.parse('$authUrl/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code, 'type': type}),
      );
      
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Verification failed'};
      }
    } catch (e) {
      print('Verify Code Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      final response = await http.post(
        Uri.parse('$authUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to send password reset code'};
      }
    } catch (e) {
      print('Forgot Password Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    try {
      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      final response = await http.post(
        Uri.parse('$authUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Password reset failed'};
      }
    } catch (e) {
      print('Reset Password Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>?> getUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userDataString = prefs.getString('userData');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  Future<String?> getUsername() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['username'];
  }

  Future<String?> getFullName() async {
    Map<String, dynamic>? userData = await getUserData();
    if (userData != null) {
      String firstName = userData['firstName'] ?? '';
      String lastName = userData['lastName'] ?? '';
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '$firstName $lastName';
      } else if (firstName.isNotEmpty) {
        return firstName;
      } else if (lastName.isNotEmpty) {
        return lastName;
      }
    }
    return null;
  }

  Future<String?> getEmployeeId() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['employeeId'];
  }

  Future<String?> getDepartment() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['department'];
  }

  Future<int> getJobsCompleted() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['jobsCompleted'] ?? 0;
  }

  Future<double> getWeeklyPerformance() async {
    Map<String, dynamic>? userData = await getUserData();
    return (userData?['weeklyPerformance'] ?? 0).toDouble();
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      String? token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final baseUrl = await ConfigService.getBaseUrl();
      final authUrl = '$baseUrl/api/auth';
      final response = await http.get(
        Uri.parse('$authUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Update stored user data
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(responseData));
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get profile'};
      }
    } catch (e) {
      print('Get Profile Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
} 