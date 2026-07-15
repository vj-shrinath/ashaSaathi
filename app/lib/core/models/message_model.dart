enum MessageType { text, voice, triageResult, systemInfo, doctorSuggestion }

class TriageResult {
  final String patientSummary;
  final List<String> symptoms;
  final Map<String, dynamic> vitals;
  final String severity;
  final int riskScore;
  final String riskCategory; // Green, Yellow, Orange, Red
  final String suggestedAction;
  final bool doctorRequired;
  final bool emergencyRequired;
  final bool ambulanceRecommendation;
  final String followUpTime;
  final String medicalNotes;
  final double confidenceScore;

  TriageResult({
    required this.patientSummary,
    required this.symptoms,
    required this.vitals,
    required this.severity,
    required this.riskScore,
    required this.riskCategory,
    required this.suggestedAction,
    required this.doctorRequired,
    required this.emergencyRequired,
    required this.ambulanceRecommendation,
    required this.followUpTime,
    required this.medicalNotes,
    required this.confidenceScore,
  });

  factory TriageResult.fromMap(Map<String, dynamic> map) {
    return TriageResult(
      patientSummary: map['patientSummary'] ?? '',
      symptoms: List<String>.from(map['symptoms'] ?? []),
      vitals: Map<String, dynamic>.from(map['vitals'] ?? {}),
      severity: map['severity'] ?? 'Low',
      riskScore: (map['riskScore'] ?? 1) is int
          ? map['riskScore']
          : (map['riskScore'] as num).toInt(),
      riskCategory: map['riskCategory'] ?? 'Green',
      suggestedAction: map['suggestedAction'] ?? '',
      doctorRequired: map['doctorRequired'] ?? false,
      emergencyRequired: map['emergencyRequired'] ?? false,
      ambulanceRecommendation: map['ambulanceRecommendation'] ?? false,
      followUpTime: map['followUpTime'] ?? '24 hours',
      medicalNotes: map['medicalNotes'] ?? '',
      confidenceScore: (map['confidenceScore'] ?? 0.0) is double
          ? map['confidenceScore']
          : (map['confidenceScore'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'patientSummary': patientSummary,
        'symptoms': symptoms,
        'vitals': vitals,
        'severity': severity,
        'riskScore': riskScore,
        'riskCategory': riskCategory,
        'suggestedAction': suggestedAction,
        'doctorRequired': doctorRequired,
        'emergencyRequired': emergencyRequired,
        'ambulanceRecommendation': ambulanceRecommendation,
        'followUpTime': followUpTime,
        'medicalNotes': medicalNotes,
        'confidenceScore': confidenceScore,
  };
}

class ChatMessage {
  final String id;
  final MessageType type;
  final String? patientId;
  final String? visitId;
  final String? textContent;
  final String? audioUrl;
  final String? transcript;
  final TriageResult? triageResult;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isProcessing;

  ChatMessage({
    required this.id,
    required this.type,
    this.patientId,
    this.visitId,
    this.textContent,
    this.audioUrl,
    this.transcript,
    this.triageResult,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.isProcessing = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      id: data['id'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      patientId: data['patient_id'] ?? data['patientId'],
      visitId: data['visit_id'] ?? data['visitId'],
      textContent: data['text_content'] ?? data['textContent'],
      audioUrl: data['audio_url'] ?? data['audioUrl'],
      transcript: data['transcript'],
      triageResult: data['triage_result'] != null
          ? TriageResult.fromMap(
              Map<String, dynamic>.from(data['triage_result']))
          : data['triageResult'] != null
              ? TriageResult.fromMap(
                  Map<String, dynamic>.from(data['triageResult']))
          : null,
      senderId: data['sender_id'] ?? data['senderId'] ?? '',
      senderName: data['sender_name'] ?? data['senderName'] ?? 'ASHA Worker',
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isProcessing: data['is_processing'] ?? data['isProcessing'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'role': senderId == 'system' ? 'system' : 'user',
        'type': type.name,
        'patient_id': patientId,
        'visit_id': visitId,
        'text_content': textContent,
        'audio_url': audioUrl,
        'transcript': transcript,
        'triage_result': triageResult?.toMap(),
        'sender_id': senderId,
        'sender_name': senderName,
        'timestamp': timestamp.toIso8601String(),
        'is_processing': isProcessing,
      };
}
