import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';

/// Calls the Node.js backend API for voice transcription + triage analysis.
class BackendApiService {
  static String get _baseUrl => dotenv.env['BACKEND_API_URL'] ?? 'http://192.168.1.5:3000';

  /// Sends an uploaded audio URL to backend for:
  /// 1. Sarvam AI Speech-to-Text
  /// 2. Gemini AI Triage Analysis
  /// 3. Auto-save to the backend data store
  static Future<TriageResult> transcribeAndAnalyze({
    required String audioUrl,
    required String visitId,
    required String patientId,
    required String ashaId,
    required String patientName,
    required String ashaName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/visit/voice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audioUrl': audioUrl,
          'visitId': visitId,
          'patientId': patientId,
          'ashaId': ashaId,
          'patientName': patientName,
          'ashaName': ashaName,
        }),
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TriageResult.fromMap(
            Map<String, dynamic>.from(data['triageResult'] ?? {}));
      } else {
        throw Exception('Backend error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Voice analysis failed: $e');
    }
  }

  /// Registers user account via Node backend using Service Role key
  /// to bypass standard OTP or SMTP mail rate-limitations.
  static Future<void> registerWorker({
    required String phone,
    required String password,
    required String fullName,
    required String role,
    String? phcId,
    String? doctorId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/register-worker'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'fullName': fullName,
        'role': role,
        'phc_id': phcId,
        'doctor_id': doctorId,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      final message = data['message'] ?? 'Registration failed';
      if (response.statusCode == 422 || message.toLowerCase().contains('already')) {
        throw AuthException(
          message,
          statusCode: response.statusCode.toString(),
        );
      }
      throw AuthException(
        message,
        statusCode: response.statusCode.toString(),
      );
    }
  }

  /// Resolves an existing worker account by phone number.
  static Future<Map<String, dynamic>> resolveWorker({
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/resolve-worker'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to resolve worker profile');
  }

  static Future<List<Map<String, dynamic>>> listPhcs() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/auth/phcs'));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      final items = (data['data'] as List<dynamic>? ?? const []);
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load PHCs');
  }

  static Future<List<Map<String, dynamic>>> listDoctorsByPhc({
    required String phcId,
  }) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/v1/auth/phcs/$phcId/doctors'));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      final items = (data['data'] as List<dynamic>? ?? const []);
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load doctors');
  }

  static Future<Map<String, dynamic>> createPhc({
    required String name,
    required String district,
    required String taluka,
    required String village,
    required String address,
    required String adminToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/admin/phc'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
      body: jsonEncode({
        'name': name,
        'district': district,
        'taluka': taluka,
        'village': village,
        'address': address,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to create PHC');
  }

  static Future<Map<String, dynamic>> updatePhc({
    required String phcId,
    required String name,
    required String district,
    required String taluka,
    required String village,
    required String address,
    required String adminToken,
    bool isActive = true,
  }) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/v1/auth/admin/phc/$phcId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
      body: jsonEncode({
        'name': name,
        'district': district,
        'taluka': taluka,
        'village': village,
        'address': address,
        'is_active': isActive,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to update PHC');
  }

  static Future<Map<String, dynamic>> registerPhcAdmin({
    required String phone,
    required String password,
    required String fullName,
    required String phcId,
    required String adminToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/admin/phc-admin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'fullName': fullName,
        'phc_id': phcId,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to register PHC admin');
  }

  static Future<Map<String, dynamic>> createPhcPublic({
    required String name,
    required String district,
    required String taluka,
    required String village,
    required String address,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/public-phc'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'district': district,
        'taluka': taluka,
        'village': village,
        'address': address,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to create public PHC');
  }

  /// Generates a temporary Sync PIN on the backend for device transfer (Admin auth required)
  static Future<String> generateSyncToken({
    required String phone,
    required String adminToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/admin/generate-sync-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
      body: jsonEncode({'phone': phone}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return data['data']['pin'] as String;
    } else {
      throw Exception(data['message'] ?? 'Failed to generate sync code');
    }
  }

  /// Verifies a 6-digit Sync PIN on backend to retrieve temporary credentials
  static Future<Map<String, dynamic>> verifySyncToken({
    required String phone,
    required String pin,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/verify-sync-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'pin': pin}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    } else {
      throw Exception(data['message'] ?? 'Sync verification failed');
    }
  }
}
