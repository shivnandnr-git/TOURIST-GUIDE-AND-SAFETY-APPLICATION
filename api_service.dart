// lib/services/api_service.dart
// Add this file to your Flutter project under lib/services/
//
// Dependencies to add in pubspec.yaml:
//   http: ^1.1.0
//   shared_preferences: ^2.2.0

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ── Change this to your machine's IP when running on a real device ──
  // For Android emulator: use 10.0.2.2
  // For iOS simulator:    use 127.0.0.1
  // For real device:      use your computer's local IP e.g. 192.168.1.5
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // ── Token helpers ───────────────────────────────────────────────────

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── AUTH ────────────────────────────────────────────────────────────

  /// Register a new user
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String confirmPassword,
    required String bloodGroup,
    String? medicalCondition,
    required String emergencyContact1,
    String? emergencyContact2,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'mobile': mobile,
        'password': password,
        'confirm_password': confirmPassword,
        'blood_group': bloodGroup,
        'medical_condition': medicalCondition ?? '',
        'emergency_contact_1': emergencyContact1,
        'emergency_contact_2': emergencyContact2 ?? '',
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      await saveTokens(data['tokens']['access'], data['tokens']['refresh']);
    }
    return {'status': response.statusCode, 'data': data};
  }

  /// Login with email and password
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveTokens(data['tokens']['access'], data['tokens']['refresh']);
    }
    return {'status': response.statusCode, 'data': data};
  }

  /// Logout and clear tokens
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token');
    final headers = await authHeaders();
    await http.post(
      Uri.parse('$baseUrl/auth/logout/'),
      headers: headers,
      body: jsonEncode({'refresh': refresh}),
    );
    await clearTokens();
  }

  // ── PROFILE ─────────────────────────────────────────────────────────

  /// Get current user profile
  static Future<Map<String, dynamic>> getProfile() async {
    final headers = await authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/profile/'),
      headers: headers,
    );
    return {'status': response.statusCode, 'data': jsonDecode(response.body)};
  }

  /// Update user profile (matches profile_edit_screen.dart fields)
  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? mobile,
    String? bloodGroup,
    String? medicalCondition,
    String? emergencyContact1,
    String? emergencyContact2,
    String? location,
    File? profileImage,
  }) async {
    final token = await getAccessToken();
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('$baseUrl/profile/'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    if (fullName != null) request.fields['full_name'] = fullName;
    if (mobile != null) request.fields['mobile'] = mobile;
    if (bloodGroup != null) request.fields['blood_group'] = bloodGroup;
    if (medicalCondition != null) request.fields['medical_condition'] = medicalCondition;
    if (emergencyContact1 != null) request.fields['emergency_contact_1'] = emergencyContact1;
    if (emergencyContact2 != null) request.fields['emergency_contact_2'] = emergencyContact2;
    if (location != null) request.fields['location'] = location;
    if (profileImage != null) {
      request.files.add(await http.MultipartFile.fromPath('profile_image', profileImage.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return {'status': response.statusCode, 'data': jsonDecode(response.body)};
  }

  // ── PHOTO DIARY ──────────────────────────────────────────────────────

  /// Get all photos (optionally filtered by search query)
  static Future<Map<String, dynamic>> getPhotos({String? search}) async {
    final headers = await authHeaders();
    final uri = Uri.parse('$baseUrl/photos/').replace(
      queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
    );
    final response = await http.get(uri, headers: headers);
    return {'status': response.statusCode, 'data': jsonDecode(response.body)};
  }

  /// Upload a new photo to diary
  static Future<Map<String, dynamic>> uploadPhoto({
    required File imageFile,
    required String caption,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    final token = await getAccessToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/photos/'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['caption'] = caption;
    request.fields['location'] = location;
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return {'status': response.statusCode, 'data': jsonDecode(response.body)};
  }

  /// Delete a photo
  static Future<int> deletePhoto(int photoId) async {
    final headers = await authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/photos/$photoId/'),
      headers: headers,
    );
    return response.statusCode;
  }

  // ── SOS EMERGENCY ────────────────────────────────────────────────────

  /// Send SOS alert — matches _sendSOSSignal() in tourmate_dashboard.dart
  static Future<Map<String, dynamic>> sendSOS({
    required double latitude,
    required double longitude,
    String? locationDescription,
    String? message,
  }) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/sos/'),
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'location_description': locationDescription ?? '',
        'message': message ?? 'Emergency SOS triggered.',
      }),
    );
    return {'status': response.statusCode, 'data': jsonDecode(response.body)};
  }

  /// Get SOS alert history
  static Future<Map<String, dynamic>> getSOSHistory() async {
    final headers = await authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/sos/history/'),
      headers: headers,
    );
    return {'status': response.statusCode, 'data': jsonDecode(response.body)};
  }
}
