import 'package:flutter/material.dart';

enum ActivityType {
  login('login', 'Login'),
  logout('logout', 'Logout'),
  patientCreated('patient_created', 'Patient Created'),
  patientUpdated('patient_updated', 'Patient Updated'),
  visitStarted('visit_started', 'Visit Started'),
  visitCompleted('visit_completed', 'Visit Completed'),
  voiceNoteRecorded('voice_note_recorded', 'Voice Note Recorded'),
  triageGenerated('triage_generated', 'Triage Generated'),
  triageReviewed('triage_reviewed', 'Triage Reviewed'),
  prescriptionCreated('prescription_created', 'Prescription Created'),
  prescriptionUpdated('prescription_updated', 'Prescription Updated'),
  emergencyTriggered('emergency_triggered', 'Emergency Triggered'),
  roleChanged('role_changed', 'Role Changed'),
  userManaged('user_managed', 'User Managed');

  const ActivityType(this.value, this.displayName);
  final String value;
  final String displayName;

  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (t) => t.value == value,
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

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }

  IconData get icon {
    switch (type) {
      case ActivityType.login:
        return Icons.login;
      case ActivityType.logout:
        return Icons.logout;
      case ActivityType.patientCreated:
        return Icons.person_add;
      case ActivityType.patientUpdated:
        return Icons.edit;
      case ActivityType.visitStarted:
        return Icons.play_circle;
      case ActivityType.visitCompleted:
        return Icons.check_circle;
      case ActivityType.voiceNoteRecorded:
        return Icons.mic;
      case ActivityType.triageGenerated:
        return Icons.analytics;
      case ActivityType.triageReviewed:
        return Icons.medical_services;
      case ActivityType.prescriptionCreated:
        return Icons.medication;
      case ActivityType.prescriptionUpdated:
        return Icons.edit_note;
      case ActivityType.emergencyTriggered:
        return Icons.emergency;
      case ActivityType.roleChanged:
        return Icons.swap_horiz;
      case ActivityType.userManaged:
        return Icons.people;
    }
  }

  Color get color {
    switch (type) {
      case ActivityType.login:
        return Colors.green;
      case ActivityType.logout:
        return Colors.grey;
      case ActivityType.patientCreated:
        return Colors.blue;
      case ActivityType.patientUpdated:
        return Colors.orange;
      case ActivityType.visitStarted:
        return Colors.teal;
      case ActivityType.visitCompleted:
        return Colors.green;
      case ActivityType.voiceNoteRecorded:
        return Colors.purple;
      case ActivityType.triageGenerated:
        return Colors.indigo;
      case ActivityType.triageReviewed:
        return Colors.blue;
      case ActivityType.prescriptionCreated:
        return Colors.deepPurple;
      case ActivityType.prescriptionUpdated:
        return Colors.deepOrange;
      case ActivityType.emergencyTriggered:
        return Colors.red;
      case ActivityType.roleChanged:
        return Colors.amber;
      case ActivityType.userManaged:
        return Colors.pink;
    }
  }
}