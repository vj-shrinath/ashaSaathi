/// One saved instance of a register form for one patient/household. 
/// Maps 1:1 to a row in the `register_entries` Supabase table.
class RegisterEntry { 
  final String? id; // Supabase row UUID, null until first save
  final String registerId; // e.g. 'anc', 'ncd' — matches RegisterConfig.id 
  final String? familyId; // links back to households.id, if applicable
  final String? patientName; 
  final Map<String, dynamic> fieldValues; // { fieldId: value }
  final String createdByAshaId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RegisterEntry({
    this.id,
    required this.registerId,
    this.familyId,
    this.patientName,
    required this.fieldValues,
    required this.createdByAshaId,
    this.createdAt,
    this.updatedAt,
  });

  factory RegisterEntry.fromMap(Map<String, dynamic> map) => RegisterEntry(
        id: map['id'] as String?,
        registerId: map['register_id'] as String,
        familyId: map['family_id'] as String?,
        patientName: map['patient_name'] as String?,
        fieldValues: Map<String, dynamic>.from(map['field_values'] ?? {}),
        createdByAshaId: map['created_by_asha_id'] as String,
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'register_id': registerId,
        if (familyId != null) 'family_id': familyId,
        if (patientName != null) 'patient_name': patientName,
        'field_values': fieldValues,
        'created_by_asha_id': createdByAshaId,
      };
}

/// A high-risk alert pushed to the Doctor/CHO Dashboard when an ASHA saves
/// a reading past a safety threshold (Hb < 7, BP >= 140/90, etc).
/// Maps 1:1 to a row in the `high_risk_alerts` Supabase table.
class HighRiskAlert {
  final String? id;
  final String registerId;
  final String? registerEntryId;
  final String patientName;
  final String? patientAge;
  final String? houseNo;
  final String? village;
  final String ashaWorkerName;
  final String? ashaWorkerContact;
  final List<String> reasons; // e.g. ["Hb = 6.2 g/dL (Severe Anemia)"]
  final bool reviewed;
  final String? doctorNote;
  final DateTime? createdAt;

  HighRiskAlert({
    this.id,
    required this.registerId,
    this.registerEntryId,
    required this.patientName,
    this.patientAge,
    this.houseNo,
    this.village,
    required this.ashaWorkerName,
    this.ashaWorkerContact,
    required this.reasons,
    this.reviewed = false,
    this.doctorNote,
    this.createdAt,
  });

  factory HighRiskAlert.fromMap(Map<String, dynamic> map) => HighRiskAlert(
        id: map['id'] as String?,
        registerId: map['register_id'] as String,
        registerEntryId: map['register_entry_id'] as String?,
        patientName: map['patient_name'] as String,
        patientAge: map['patient_age'] as String?,
        houseNo: map['house_no'] as String?,
        village: map['village'] as String?,
        ashaWorkerName: map['asha_worker_name'] as String,
        ashaWorkerContact: map['asha_worker_contact'] as String?,
        reasons: List<String>.from(map['reasons'] ?? []),
        reviewed: map['reviewed'] as bool? ?? false,
        doctorNote: map['doctor_note'] as String?,
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'register_id': registerId,
        if (registerEntryId != null) 'register_entry_id': registerEntryId,
        'patient_name': patientName,
        if (patientAge != null) 'patient_age': patientAge,
        if (houseNo != null) 'house_no': houseNo,
        if (village != null) 'village': village,
        'asha_worker_name': ashaWorkerName,
        if (ashaWorkerContact != null) 'asha_worker_contact': ashaWorkerContact,
        'reasons': reasons,
      };
}

/// A "Send PDF to ANM" event — every register submission (not just high-risk
/// ones) logs here, so the Doctor/CHO Office Inbox shows everything received.
/// Maps 1:1 to a row in the `office_inbox` Supabase table.
class OfficeInboxEntry {
  final String? id;
  final String registerId;
  final String registerTitle;
  final String patientName;
  final String pdfUrl; // Supabase Storage public/signed URL
  final DateTime? createdAt;

  OfficeInboxEntry({
    this.id,
    required this.registerId,
    required this.registerTitle,
    required this.patientName,
    required this.pdfUrl,
    this.createdAt,
  });

  factory OfficeInboxEntry.fromMap(Map<String, dynamic> map) => OfficeInboxEntry(
        id: map['id'] as String?,
        registerId: map['register_id'] as String,
        registerTitle: map['register_title'] as String,
        patientName: map['patient_name'] as String,
        pdfUrl: map['pdf_url'] as String,
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      );
}
