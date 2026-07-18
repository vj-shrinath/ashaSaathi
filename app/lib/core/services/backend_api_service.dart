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
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/register-worker'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'fullName': fullName,
        'role': role,
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
