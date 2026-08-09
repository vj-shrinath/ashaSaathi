import 'message_model.dart';

class Patient {
  final String id;
  final String name;
  final int age;
  final String village;
  final String? registerType;
  final String ashaId;
  final String riskCategory;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? photoUrl;
  final Map<String, dynamic>? caseDetails;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.village,
    this.registerType,
    required this.ashaId,
    this.riskCategory = 'Green',
    this.lastMessage,
    this.lastMessageTime,
    this.photoUrl,
    this.caseDetails,
  });

  factory Patient.fromMap(Map<String, dynamic> data) {
    return Patient(
      id: data['id'] ?? '',
      name: data['name'] ?? 'Unknown',
      age: (data['age'] ?? 0) is int
          ? data['age']
          : (data['age'] as num).toInt(),
      village: data['village'] ?? '',
      registerType: data['register_type'] ?? data['registerType'],
      ashaId: data['asha_id'] ?? data['ashaId'] ?? '',
      riskCategory: data['risk_category'] ?? data['riskCategory'] ?? 'Green',
      lastMessage: data['last_message'] ?? data['lastMessage'],
      lastMessageTime: data['last_message_time'] != null
          ? DateTime.tryParse(data['last_message_time'].toString())
          : (data['lastMessageTime'] is DateTime
              ? data['lastMessageTime']
              : null),
      photoUrl: data['photo_url'] ?? data['photoUrl'],
      caseDetails: data['case_details'] != null
          ? Map<String, dynamic>.from(data['case_details'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'age': age,
      'village': village,
      'register_type': registerType,
      'asha_id': ashaId,
      'risk_category': riskCategory,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'photo_url': photoUrl,
    };
    if (caseDetails != null) {
      map['case_details'] = caseDetails;
    }
    map.removeWhere((key, value) => value == null);
    return map;
  }
}

class TriageReport {
  final String id;
  final String visitId;
  final String patientId;
  final String patientName;
  final String ashaId;
  final String ashaName;
  final String transcript;
  final TriageResult triageResult;
  final DateTime createdAt;
  final bool reviewedByDoctor;
  final Map<String, dynamic>? doctorSheet;

  TriageReport({
    required this.id,
    required this.visitId,
    required this.patientId,
    required this.patientName,
    required this.ashaId,
    required this.ashaName,
    required this.transcript,
    required this.triageResult,
    required this.createdAt,
    this.reviewedByDoctor = false,
    this.doctorSheet,
  });

  factory TriageReport.fromMap(Map<String, dynamic> data) {
    final rawResult = data['triage_result'] ?? data['triageResult'] ?? {};
    return TriageReport(
      id: data['id'] ?? '',
      visitId: data['visit_id'] ?? data['visitId'] ?? '',
      patientId: data['patient_id'] ?? data['patientId'] ?? '',
      patientName: data['patient_name'] ?? data['patientName'] ?? 'Unknown',
      ashaId: data['asha_id'] ?? data['ashaId'] ?? '',
      ashaName: data['asha_name'] ?? data['ashaName'] ?? 'ASHA Worker',
      transcript: data['transcript'] ?? '',
      triageResult: TriageResult.fromMap(Map<String, dynamic>.from(rawResult)),
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reviewedByDoctor: data['reviewed_by_doctor'] ?? data['reviewedByDoctor'] ?? false,
      doctorSheet: data['doctor_sheet'] != null
          ? Map<String, dynamic>.from(data['doctor_sheet'])
          : null,
    );
  }
}
