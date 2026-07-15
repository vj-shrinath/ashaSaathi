
class Prescription {
  final String id;
  final String patientId;
  final String visitId;
  final String doctorId;
  final String doctorName;
  final String patientName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Medication> medications;
  final String diagnosis;
  final String notes;
  final String followUpInstructions;
  final DateTime? followUpDate;
  final PrescriptionStatus status;

  Prescription({
    required this.id,
    required this.patientId,
    required this.visitId,
    required this.doctorId,
    required this.doctorName,
    required this.patientName,
    required this.createdAt,
    this.updatedAt,
    required this.medications,
    required this.diagnosis,
    required this.notes,
    required this.followUpInstructions,
    this.followUpDate,
    this.status = PrescriptionStatus.active,
  });

  factory Prescription.fromMap(Map<String, dynamic> data) {
    return Prescription(
      id: data['id'] ?? '',
      patientId: data['patient_id'] ?? data['patientId'] ?? '',
      visitId: data['visit_id'] ?? data['visitId'] ?? '',
      doctorId: data['doctor_id'] ?? data['doctorId'] ?? '',
      doctorName: data['doctor_name'] ?? data['doctorName'] ?? '',
      patientName: data['patient_name'] ?? data['patientName'] ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'].toString())
          : null,
      medications: (data['medications'] as List<dynamic>? ?? [])
          .map((m) => Medication.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      diagnosis: data['diagnosis'] ?? '',
      notes: data['notes'] ?? '',
      followUpInstructions: data['follow_up_instructions'] ?? data['followUpInstructions'] ?? '',
      followUpDate: data['follow_up_date'] != null
          ? DateTime.tryParse(data['follow_up_date'].toString())
          : null,
      status: PrescriptionStatus.fromString(data['status'] ?? 'active'),
    );
  }

  Map<String, dynamic> toMap() => {
        'patient_id': patientId,
        'visit_id': visitId,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'patient_name': patientName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'medications': medications.map((m) => m.toMap()).toList(),
        'diagnosis': diagnosis,
        'notes': notes,
        'follow_up_instructions': followUpInstructions,
        'follow_up_date': followUpDate?.toIso8601String(),
        'status': status.value,
      };

  Prescription copyWith({
    String? id,
    String? patientId,
    String? visitId,
    String? doctorId,
    String? doctorName,
    String? patientName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Medication>? medications,
    String? diagnosis,
    String? notes,
    String? followUpInstructions,
    DateTime? followUpDate,
    PrescriptionStatus? status,
  }) {
    return Prescription(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      visitId: visitId ?? this.visitId,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      patientName: patientName ?? this.patientName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      medications: medications ?? this.medications,
      diagnosis: diagnosis ?? this.diagnosis,
      notes: notes ?? this.notes,
      followUpInstructions: followUpInstructions ?? this.followUpInstructions,
      followUpDate: followUpDate ?? this.followUpDate,
      status: status ?? this.status,
    );
  }
}

class Medication {
  final String id;
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;
  final MedicationType type;
  final bool isPrescribed;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
    this.type = MedicationType.tablet,
    this.isPrescribed = true,
  });

  factory Medication.fromMap(Map<String, dynamic> data) {
    return Medication(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      frequency: data['frequency'] ?? '',
      duration: data['duration'] ?? '',
      instructions: data['instructions'] ?? '',
      type: MedicationType.fromString(data['type'] ?? 'tablet'),
      isPrescribed: data['is_prescribed'] ?? data['isPrescribed'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
        'type': type.value,
        'is_prescribed': isPrescribed,
      };
}

enum MedicationType {
  tablet('tablet', 'Tablet'),
  capsule('capsule', 'Capsule'),
  syrup('syrup', 'Syrup'),
  injection('injection', 'Injection'),
  drops('drops', 'Drops'),
  ointment('ointment', 'Ointment'),
  inhaler('inhaler', 'Inhaler'),
  other('other', 'Other');

  const MedicationType(this.value, this.displayName);
  final String value;
  final String displayName;

  static MedicationType fromString(String type) {
    return MedicationType.values.firstWhere(
      (t) => t.value == type,
      orElse: () => MedicationType.tablet,
    );
  }
}

enum PrescriptionStatus {
  active('active', 'Active'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  expired('expired', 'Expired');

  const PrescriptionStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static PrescriptionStatus fromString(String status) {
    return PrescriptionStatus.values.firstWhere(
      (s) => s.value == status,
      orElse: () => PrescriptionStatus.active,
    );
  }
}