enum ActivityType {
  login('login', 'Login'),
  logout('logout', 'Logout'),
  patientAdded('patient_added', 'Patient Added'),
  patientUpdated('patient_updated', 'Patient Updated'),
  visitStarted('visit_started', 'Visit Started'),
  visitCompleted('visit_completed', 'Visit Completed'),
  voiceNoteRecorded('voice_note_recorded', 'Voice Note Recorded'),
  triageGenerated('triage_generated', 'Triage Generated'),
  prescriptionCreated('prescription_created', 'Prescription Created'),
  prescriptionUpdated('prescription_updated', 'Prescription Updated'),
  emergencyTriggered('emergency_triggered', 'Emergency Triggered'),
  reportReviewed('report_reviewed', 'Report Reviewed'),
  roleChanged('role_changed', 'Role Changed'),
  userCreated('user_created', 'User Created');

  const ActivityType(this.value, this.displayName);
  final String value;
  final String displayName;

  static ActivityType fromString(String type) {
    return ActivityType.values.firstWhere(
      (t) => t.value == type,
      orElse: () => ActivityType.login,
    );
  }
}

class ActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final ActivityType type;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String? patientId;
  final String? visitId;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.type,
    required this.description,
    required this.metadata,
    required this.timestamp,
    this.patientId,
    this.visitId,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> data) {
    return ActivityLog(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      userName: data['user_name'] ?? data['userName'] ?? '',
      userRole: data['user_role'] ?? data['userRole'] ?? '',
      type: ActivityType.fromString(data['type'] ?? 'login'),
      description: data['description'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      patientId: data['patient_id'] ?? data['patientId'],
      visitId: data['visit_id'] ?? data['visitId'],
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'user_name': userName,
        'user_role': userRole,
        'type': type.value,
        'description': description,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
        'patient_id': patientId,
        'visit_id': visitId,
      };
}