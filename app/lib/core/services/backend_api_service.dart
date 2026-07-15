import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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
}
