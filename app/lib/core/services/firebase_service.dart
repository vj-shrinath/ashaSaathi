import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/patient_model.dart';
import '../models/prescription.dart';
import '../models/activity_log.dart';
import '../models/user_role.dart';
import '../models/gramnidan_register.dart';

class FirebaseService {
  static final SupabaseClient _db = Supabase.instance.client;
  static const _uuid = Uuid();

  static String get _ownerId {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in Supabase user');
    }
    return user.id;
  }

  static String get _voiceBucket => 'voice-notes';

  // ─── Auth & Role ─────────────────────────────────────────────────────────────
  static Future<UserRole?> getCurrentUserRole() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final roleStr = user.userMetadata?['role'] as String?;
    return roleStr != null ? UserRole.fromString(roleStr) : UserRole.asha;
  }

  static Future<void> setUserRole(UserRole role) async {
    await _db.auth.updateUser(
      UserAttributes(data: {'role': role.value}),
    );
  }

  static String getCurrentUserId() => _ownerId;
  static String getCurrentUserName() => _db.auth.currentUser?.userMetadata?['full_name'] ?? 'User';

  // ─── Audio ───────────────────────────────────────────────────────────────────
  static Future<String> uploadAudio(File audioFile, String visitId) async {
    final fileName = '${_uuid.v4()}.m4a';
    final path = 'voice_notes/$visitId/$fileName';
    await _db.storage.from(_voiceBucket).upload(
          path,
          audioFile,
          fileOptions: const FileOptions(contentType: 'audio/m4a'),
        );
    final signedUrl = await _db.storage
        .from(_voiceBucket)
        .createSignedUrl(path, 60 * 60);
    return signedUrl;
  }

  // ─── Messages ────────────────────────────────────────────────────────────────
  static Future<String> saveMessage(
    String visitId,
    ChatMessage message, {
    String? patientId,
  }) async {
    try {
      final payload = {
        ...message.toMap(),
        'patient_id': patientId ?? message.patientId,
        'visit_id': visitId,
        'owner_id': _ownerId,
      };
      final row = await _db.from('messages').insert(payload).select('id').single();
      return row['id'] as String;
    } catch (e) {
      debugPrint('saveMessage DB notice: $e');
      return message.id.isNotEmpty ? message.id : _uuid.v4();
    }
  }

  static Future<void> updateMessage(
      String visitId, String messageId, Map<String, dynamic> data) async {
    await _db
        .from('messages')
        .update(data)
        .eq('visit_id', visitId)
        .eq('id', messageId);
  }

  static Stream<List<ChatMessage>> watchMessages(String visitId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('visit_id', visitId)
        .order('timestamp', ascending: false)
        .map((rows) => rows
            .map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  static Stream<List<ChatMessage>> watchPatientMessages(String patientId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('timestamp', ascending: false)
        .map((rows) => rows
            .map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  static Future<List<ChatMessage>> getPatientMessages(String patientId) async {
    final rows = await _db
        .from('messages')
        .select()
        .eq('patient_id', patientId)
        .order('timestamp', ascending: false);
    return (rows as List)
        .map((row) => ChatMessage.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  // ─── Patients ────────────────────────────────────────────────────────────────

  /// Stable patient list stream that does NOT flicker.
  ///
  /// Supabase Realtime `.stream().eq()` re-emits the FULL list whenever ANY row
  /// in the `patients` table changes (even rows owned by other ASHAs), causing
  /// the UI to flash/reorder constantly. Instead, we:
  ///   1. Fetch once immediately.
  ///   2. Listen to Realtime Postgres changes scoped to only `asha_id = ashaId`.
  ///   3. On any relevant change, refetch — giving us stable, debounced updates.
  static Stream<List<Patient>> watchPatients(String ashaId) {
    final controller = StreamController<List<Patient>>.broadcast();
    List<Patient>? cache;

    Future<void> fetch() async {
      try {
        final rows = await _db
            .from('patients')
            .select()
            .eq('asha_id', ashaId)
            .order('last_message_time', ascending: false, nullsFirst: false);
        final patients = (rows as List)
            .map((row) => Patient.fromMap(Map<String, dynamic>.from(row)))
            .toList();
        // Only emit if the data actually changed (avoid pointless rebuilds)
        if (cache == null || patients.length != cache!.length ||
            !List.generate(patients.length, (i) => patients[i].id)
                .every((id) => cache!.any((p) => p.id == id))) {
          cache = patients;
          if (!controller.isClosed) controller.add(patients);
        }
      } catch (e) {
        debugPrint('watchPatients fetch error: $e');
      }
    }

    // Initial fetch
    fetch();

    // Subscribe to Realtime changes scoped to this ASHA's rows only
    final channel = _db
        .channel('patients_asha_$ashaId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'patients',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'asha_id',
            value: ashaId,
          ),
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      _db.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  static Future<Patient?> getPatient(String patientId) async {
    try {
      final row = await _db.from('patients').select().eq('id', patientId).maybeSingle();
      if (row == null) return null;
      return Patient.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('getPatient error: $e');
      return null;
    }
  }

  static Future<Patient?> getPatientForDoctor(String patientId, String doctorId) async {
    try {
      final patient = await getPatient(patientId);
      if (patient != null) return patient;
      final rows = await _db
          .from('triage_reports')
          .select()
          .eq('patient_id', patientId)
          .limit(1);
      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first);
        return Patient(
          id: patientId,
          name: row['patient_name']?.toString() ?? 'Patient',
          age: 0,
          village: '',
          ashaId: row['asha_id']?.toString() ?? '',
          riskCategory: 'Green',
        );
      }
    } catch (e) {
      debugPrint('getPatientForDoctor error: $e');
    }
    return null;
  }

  static Future<String> createPatient(Patient patient) async {
    final payload = patient.toMap();
    payload['owner_id'] = _ownerId;
    payload['last_message_time'] ??= DateTime.now().toIso8601String();
    payload.removeWhere((key, value) => value == null);
    final row = await _db.from('patients').insert(payload).select('id').single();
    return row['id'] as String;
  }

  static Future<void> updatePatient(String patientId,
      {String? riskCategory, String? lastMessage}) async {
    final data = <String, dynamic>{
      'last_message_time': DateTime.now().toIso8601String(),
    };
    if (riskCategory != null) data['risk_category'] = riskCategory;
    if (lastMessage != null) data['last_message'] = lastMessage;
    await _db.from('patients').update(data).eq('id', patientId);
  }

  static Stream<List<Patient>> watchAllPatients() {
    return _db.from('patients').stream(primaryKey: ['id']).map((rows) {
      final patients =
          rows.map((row) => Patient.fromMap(Map<String, dynamic>.from(row))).toList();
      patients.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return patients;
    });
  }

  // ─── Visits ──────────────────────────────────────────────────────────────────
  static Future<String> createVisit(String patientId, String ashaId) async {
    final row = await _db.from('visits').insert({
      'owner_id': _ownerId,
      'patient_id': patientId,
      'asha_id': ashaId,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'active',
    }).select('id').single();
    return row['id'] as String;
  }

  static Future<void> completeVisit(String visitId) async {
    await _db.from('visits').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', visitId);
  }

  static Stream<List<Map<String, dynamic>>> watchVisits(String patientId) {
    return _db
        .from('visits')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  static Future<String?> getLatestVisitIdForPatient(String patientId) async {
    final rows = await _db
        .from('visits')
        .select('id, created_at')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) {
      return rows.first['id'] as String?;
    }
    return null;
  }

  // ─── Triage Reports ──────────────────────────────────────────────────────────

  /// Global triage report stream (for fallback/admin use).
  static Stream<List<TriageReport>> watchTriageReports() {
    return _db
        .from('triage_reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((row) => TriageReport.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  /// Scoped triage reports for a doctor — only fetches rows matching this
  /// doctor's ASHA scope. Prevents the 0-count race on login by only emitting
  /// once we have a real ashaIds set, and by using a stable fetch+Realtime
  /// approach instead of a global stream filtered clientside.
  static Stream<List<TriageReport>> watchTriageReportsForAshas(
      Set<String> ashaIds) {
    if (ashaIds.isEmpty) {
      // Return a stream that emits an empty list immediately (no flicker)
      return Stream.value([]);
    }

    final controller = StreamController<List<TriageReport>>.broadcast();
    List<String>? cachedIds;

    Future<void> fetch() async {
      try {
        final rows = await _db
            .from('triage_reports')
            .select()
            .inFilter('asha_id', ashaIds.toList())
            .order('created_at', ascending: false);
        final reports = (rows as List)
            .map((row) => TriageReport.fromMap(Map<String, dynamic>.from(row)))
            .toList();
        final ids = reports.map((r) => r.id).toList();
        if (cachedIds == null || ids.length != cachedIds!.length ||
            !ids.every((id) => cachedIds!.contains(id))) {
          cachedIds = ids;
          if (!controller.isClosed) controller.add(reports);
        }
      } catch (e) {
        debugPrint('watchTriageReportsForAshas fetch error: $e');
      }
    }

    fetch();

    final channel = _db
        .channel('triage_reports_doctor')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'triage_reports',
          callback: (payload) {
            // Only re-fetch if the changed row belongs to our scoped ASHAs
            final ashaId = payload.newRecord['asha_id'] as String? ??
                payload.oldRecord['asha_id'] as String?;
            if (ashaId == null || ashaIds.contains(ashaId)) {
              fetch();
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _db.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  static Stream<List<TriageReport>> watchTriageReportsForPatient(String patientId) {
    return watchTriageReports().map(
      (reports) => reports.where((r) => r.patientId == patientId).toList(),
    );
  }

  static Future<List<TriageReport>> getTriageReportsForPatient(String patientId) async {
    final rows = await _db
        .from('triage_reports')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => TriageReport.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<TriageReport?> getTriageReportByVisitId(String visitId) async {
    try {
      final rows = await _db
          .from('triage_reports')
          .select()
          .eq('visit_id', visitId)
          .limit(1);
      if (rows.isNotEmpty) {
        return TriageReport.fromMap(Map<String, dynamic>.from(rows.first));
      }
    } catch (e) {
      debugPrint('getTriageReportByVisitId DB notice: $e');
    }
    return null;
  }

  static Future<void> markReportReviewed(String reportId) async {
    try {
      await _db
          .from('triage_reports')
          .update({
            'reviewed_by_doctor': true,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);
    } catch (e) {
      debugPrint('markReportReviewed DB notice: $e');
    }
  }

  static Future<void> saveDoctorSheet(String reportId, Map<String, dynamic> doctorSheet) async {
    try {
      await _db
          .from('triage_reports')
          .update({'doctor_sheet': doctorSheet})
          .eq('id', reportId);
    } catch (e) {
      debugPrint('saveDoctorSheet DB notice: $e');
    }
  }

  // ─── Prescriptions ───────────────────────────────────────────────────────────
  static Future<String> createPrescription(Prescription prescription) async {
    try {
      final payload = prescription.toMap();
      payload['owner_id'] = _ownerId;
      final row = await _db
          .from('prescriptions')
          .insert(payload)
          .select('id')
          .single();
      await _logActivity(ActivityLog(
        id: '',
        userId: _ownerId,
        userName: getCurrentUserName(),
        userRole: (await getCurrentUserRole())?.value ?? 'doctor',
        type: ActivityType.prescriptionCreated,
        description: 'Created prescription for ${prescription.patientName}',
        metadata: {'prescriptionId': prescription.id, 'patientId': prescription.patientId},
        timestamp: DateTime.now(),
        patientId: prescription.patientId,
        visitId: prescription.visitId,
      ));
      return row['id'] as String;
    } catch (e) {
      debugPrint('createPrescription DB notice: $e');
      return prescription.id.isNotEmpty ? prescription.id : _uuid.v4();
    }
  }

  static Future<void> updatePrescription(String prescriptionId,
      {List<Medication>? medications,
      String? diagnosis,
      String? notes,
      String? followUpInstructions,
      DateTime? followUpDate,
      PrescriptionStatus? status}) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (medications != null) data['medications'] = medications.map((m) => m.toMap()).toList();
      if (diagnosis != null) data['diagnosis'] = diagnosis;
      if (notes != null) data['notes'] = notes;
      if (followUpInstructions != null) data['follow_up_instructions'] = followUpInstructions;
      if (followUpDate != null) data['follow_up_date'] = followUpDate.toIso8601String();
      if (status != null) data['status'] = status.value;
      await _db.from('prescriptions').update(data).eq('id', prescriptionId);
    } catch (e) {
      debugPrint('updatePrescription DB notice: $e');
    }
  }

  static Future<Prescription?> getPrescription(String prescriptionId) async {
    try {
      final row = await _db.from('prescriptions').select().eq('id', prescriptionId).maybeSingle();
      if (row == null) return null;
      return Prescription.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('getPrescription DB notice: $e');
      return null;
    }
  }

  static Stream<List<Prescription>> watchPrescriptions({
    String? patientId,
    String? doctorId,
  }) {
    try {
      return _db
          .from('prescriptions')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
        var filtered = rows;
        if (patientId != null) {
          filtered = filtered.where((r) => r['patient_id'] == patientId).toList();
        }
        if (doctorId != null) {
          filtered = filtered.where((r) => r['doctor_id'] == doctorId).toList();
        }
        return filtered
            .map((row) => Prescription.fromMap(Map<String, dynamic>.from(row)))
            .toList();
      });
    } catch (e) {
      debugPrint('watchPrescriptions DB notice: $e');
      return Stream.value([]);
    }
  }

  // ─── Activity Logs ───────────────────────────────────────────────────────────
  static Future<void> _logActivity(ActivityLog activity) async {
    try {
      await _db.from('activity_logs').insert(activity.toMap());
    } catch (e) {
      // Silently fail - activity logging shouldn't break the app
      debugPrint('Activity log error: $e');
    }
  }

  static Future<void> logActivity(ActivityType type, String description,
      {Map<String, dynamic>? metadata,
      String? patientId,
      String? visitId}) async {
    final role = await getCurrentUserRole();
    await _logActivity(ActivityLog(
      id: '',
      userId: _ownerId,
      userName: getCurrentUserName(),
      userRole: role?.value ?? 'unknown',
      type: type,
      description: description,
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
      patientId: patientId,
      visitId: visitId,
    ));
  }

  static Stream<List<ActivityLog>> watchActivityLogs({
    String? userId,
    String? userRole,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) {
    return _db
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(limit)
        .map((rows) {
      var filtered = rows;
      if (userId != null) {
        filtered = filtered.where((r) => r['user_id'] == userId).toList();
      }
      if (userRole != null && userRole.isNotEmpty) {
        filtered = filtered.where((r) => r['user_role'] == userRole).toList();
      }
      if (startDate != null) {
        filtered = filtered.where((r) {
          final ts = DateTime.tryParse(r['timestamp'] ?? '');
          return ts != null && ts.isAfter(startDate);
        }).toList();
      }
      if (endDate != null) {
        filtered = filtered.where((r) {
          final ts = DateTime.tryParse(r['timestamp'] ?? '');
          return ts != null && ts.isBefore(endDate);
        }).toList();
      }
      return filtered
          .map((row) => ActivityLog.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    });
  }

  // ─── Reports & Analytics ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final patients = await _db.from('patients').select('id, risk_category');
    final visits = await _db.from('visits').select('id, status');
    final reports = await _db.from('triage_reports').select('id, risk_category, reviewed_by_doctor');
    final prescriptions = await _db.from('prescriptions').select('id, status');

    return {
      'totalPatients': patients.length,
      'patientsByRisk': _groupBy(patients, 'risk_category'),
      'totalVisits': visits.length,
      'activeVisits': visits.where((v) => v['status'] == 'active').length,
      'completedVisits': visits.where((v) => v['status'] == 'completed').length,
      'totalReports': reports.length,
      'reportsByRisk': _groupBy(reports, 'risk_category'),
      'pendingReviews': reports.where((r) => r['reviewed_by_doctor'] != true).length,
      'totalPrescriptions': prescriptions.length,
      'activePrescriptions': prescriptions.where((p) => p['status'] == 'active').length,
    };
  }

  static Map<String, int> _groupBy(List<Map<String, dynamic>> items, String key) {
    final map = <String, int>{};
    for (final item in items) {
      final val = item[key] ?? 'Unknown';
      map[val] = (map[val] ?? 0) + 1;
    }
    return map;
  }

  // ─── GramNidan Registers ──────────────────────────────────────────────────────

  /// Save a newly AI-filled register to Supabase.
  static Future<String> saveGramNidanRegister(GramNidanRegister register) async {
    try {
      final id = register.id.isNotEmpty ? register.id : _uuid.v4();
      final payload = register.toMap();
      payload['id'] = id;
      await _db.from('gramnidan_registers').insert(payload).timeout(const Duration(seconds: 15));
      return id;
    } catch (e) {
      debugPrint('saveGramNidanRegister error: $e');
      throw Exception('Failed to save register: $e');
    }
  }

  /// Stream all registers submitted by a given ASHA — ordered newest first.
  static Stream<List<GramNidanRegister>> watchGramNidanRegisters(String ashaId) {
    return _db
        .from('gramnidan_registers')
        .stream(primaryKey: ['id'])
        .eq('asha_id', ashaId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((row) => GramNidanRegister.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  /// Stream registers for the THO dashboard (filter options: 'all', 'submitted', 'flagged').
  static Stream<List<GramNidanRegister>> watchThoInbox({String filter = 'all'}) {
    final query = _db.from('gramnidan_registers').stream(primaryKey: ['id']);
    if (filter == 'submitted') {
      return query
          .eq('submitted_to_tho', true)
          .order('created_at', ascending: false)
          .map((rows) => rows
              .map((row) => GramNidanRegister.fromMap(Map<String, dynamic>.from(row)))
              .toList());
    } else if (filter == 'flagged') {
      return query
          .eq('is_warning', true)
          .order('created_at', ascending: false)
          .map((rows) => rows
              .map((row) => GramNidanRegister.fromMap(Map<String, dynamic>.from(row)))
              .toList());
    }
    return query
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((row) => GramNidanRegister.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  /// Mark a register as submitted to THO and optionally save the PDF URL & updated moduleData.
  static Future<void> submitGramNidanToTho(
    String registerId, {
    String? pdfUrl,
    Map<String, Map<String, String>>? moduleData,
  }) async {
    try {
      final payload = <String, dynamic>{
        'submitted_to_tho': true,
        'pdf_url': pdfUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (moduleData != null) {
        payload['module_data'] = moduleData;
      }
      await _db.from('gramnidan_registers').update(payload).eq('id', registerId);
    } catch (e) {
      debugPrint('submitGramNidanToTho error: $e');
    }
  }

  /// Update PDF URL after generation.
  static Future<void> updateGramNidanPdfUrl(String registerId, String pdfUrl) async {
    try {
      await _db.from('gramnidan_registers').update({
        'pdf_url': pdfUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', registerId);
    } catch (e) {
      debugPrint('updateGramNidanPdfUrl error: $e');
    }
  }

  /// Upload a register PDF to Supabase Storage and return its public URL.
  static Future<String?> uploadRegisterPdf(List<int> pdfBytes, String registerId) async {
    try {
      const bucket = 'register-pdfs';
      final fileName = '$registerId.pdf';
      await _db.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            Uint8List.fromList(pdfBytes),
            fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
          );
      final signedUrl = await _db.storage.from(bucket).createSignedUrl(fileName, 60 * 60 * 24 * 7); // 7 days
      return signedUrl;
    } catch (e) {
      debugPrint('uploadRegisterPdf error: $e');
      return null;
    }
  }
}
