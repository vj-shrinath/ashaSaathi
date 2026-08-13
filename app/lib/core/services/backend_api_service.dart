import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';

class GramNidanFillResult {
  final String registerId;
  final String transcript;
  final Map<String, Map<String, String>> filledModules;
  final bool hasWarnings;

  GramNidanFillResult({
    required this.registerId,
    required this.transcript,
    required this.filledModules,
    required this.hasWarnings,
  });
}

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
    required String email,
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
        'email': email,
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

  /// Device transfer has been removed.
  static Future<String> generateSyncToken({
    required String phone,
    required String adminToken,
  }) async {
    throw UnimplementedError('Device sync has been removed');
  }

  /// Device transfer has been removed.
  static Future<Map<String, dynamic>> verifySyncToken({
    required String phone,
    required String pin,
  }) async {
    throw UnimplementedError('Device sync has been removed');
  }

  /// Admin-managed worker provisioning uses the backend service directly.
  static Future<Map<String, dynamic>> createWorkerAccount({
    required String email,
    required String fullName,
    required String role,
    String? phcId,
    String? doctorId,
    required String adminToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/register-worker'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
      body: jsonEncode({
        'email': email,
        'fullName': fullName,
        'role': role,
        'phc_id': phcId,
        'doctor_id': doctorId,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to create worker account');
  }

  static Future<Map<String, dynamic>> completePasswordChange({
    required String newPassword,
    required String accessToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/complete-password-change'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'newPassword': newPassword,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return Map<String, dynamic>.from(data['data']);
    }
    throw Exception(data['message'] ?? 'Failed to update password');
  }

  // ─── GramNidan AI Register Fill ──────────────────────────────────────────────

  /// Sends a voice audio URL + register type to the backend.
  /// Backend runs Sarvam STT → Claude GramNidan fill → saves to Supabase → returns structured JSON.
  static Future<GramNidanFillResult> fillGramNidanRegisters({
    required String audioUrl,
    required String registerType, // 'anc', 'hbnc', 'village', etc.
    required String ashaId,
    String? visitId,
    String? patientId,
    String patientName = 'Unknown',
    String ashaName = 'ASHA Worker',
    String language = 'hi',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/visit/gramnidan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audioUrl': audioUrl,
          'registerType': registerType,
          'ashaId': ashaId,
          'visitId': visitId,
          'patientId': patientId,
          'patientName': patientName,
          'ashaName': ashaName,
          'language': language,
        }),
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final registerId = data['registerId']?.toString() ?? '';
        final transcript = data['transcript']?.toString() ?? '';
        final hasWarnings = data['hasWarnings'] == true;
        final rawModules = data['filledModules'] as Map<String, dynamic>? ?? {};
        final filledModules = rawModules.map((moduleId, fields) {
          final fieldMap = (fields as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, v?.toString() ?? ''),
          );
          return MapEntry(moduleId, fieldMap);
        });

        return GramNidanFillResult(
          registerId: registerId,
          transcript: transcript,
          filledModules: filledModules,
          hasWarnings: hasWarnings,
        );
      } else {
        throw Exception('GramNidan backend error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('GramNidan fill failed: $e');
    }
  }

  /// Notifies backend that a register has been submitted to THO inbox.
  static Future<void> submitRegisterToTho(String registerId, {String? pdfUrl}) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/visit/gramnidan/submit-tho'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'registerId': registerId, 'pdfUrl': pdfUrl}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      // Silently fail — Supabase update in FirebaseService is the source of truth
    }
  }
}

