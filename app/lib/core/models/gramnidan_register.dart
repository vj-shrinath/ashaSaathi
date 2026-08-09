/// Data model for a GramNidan AI-filled health register.
/// Stored in Supabase `gramnidan_registers` table.
class GramNidanRegister {
  final String id;
  final String ashaId;
  final String? patientId;
  final String patientName;
  final String registerType; // 'anc', 'hbnc', 'village', etc.
  final String? transcript;

  /// Nested map: moduleId → { fieldId → value }
  final Map<String, Map<String, String>> moduleData;

  final bool isWarning;
  final bool submittedToTho;
  final String? pdfUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GramNidanRegister({
    required this.id,
    required this.ashaId,
    this.patientId,
    required this.patientName,
    required this.registerType,
    this.transcript,
    required this.moduleData,
    this.isWarning = false,
    this.submittedToTho = false,
    this.pdfUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GramNidanRegister.fromMap(Map<String, dynamic> map) {
    // Parse nested module_data: { moduleId: { fieldId: value } }
    final rawModuleData = map['module_data'] as Map<String, dynamic>? ?? {};
    final moduleData = rawModuleData.map((moduleId, fields) {
      final fieldMap = (fields as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      );
      return MapEntry(moduleId, fieldMap);
    });

    return GramNidanRegister(
      id: map['id'] as String? ?? '',
      ashaId: map['asha_id'] as String? ?? '',
      patientId: map['patient_id'] as String?,
      patientName: map['patient_name'] as String? ?? 'Unknown',
      registerType: map['register_type'] as String? ?? 'general',
      transcript: map['transcript'] as String?,
      moduleData: moduleData,
      isWarning: map['is_warning'] as bool? ?? false,
      submittedToTho: map['submitted_to_tho'] as bool? ?? false,
      pdfUrl: map['pdf_url'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'asha_id': ashaId,
        'patient_id': patientId,
        'patient_name': patientName,
        'register_type': registerType,
        'transcript': transcript,
        'module_data': moduleData,
        'is_warning': isWarning,
        'submitted_to_tho': submittedToTho,
        'pdf_url': pdfUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  GramNidanRegister copyWith({
    String? id,
    String? ashaId,
    String? patientId,
    String? patientName,
    String? registerType,
    String? transcript,
    Map<String, Map<String, String>>? moduleData,
    bool? isWarning,
    bool? submittedToTho,
    String? pdfUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GramNidanRegister(
      id: id ?? this.id,
      ashaId: ashaId ?? this.ashaId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      registerType: registerType ?? this.registerType,
      transcript: transcript ?? this.transcript,
      moduleData: moduleData ?? this.moduleData,
      isWarning: isWarning ?? this.isWarning,
      submittedToTho: submittedToTho ?? this.submittedToTho,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Display label for the register type
  String get displayName {
    const labels = {
      'village': 'Village Survey',
      'ec': 'Eligible Couple',
      'anc': 'ANC Register',
      'delivery': 'Delivery & PNC',
      'hbnc': 'HBNC (Newborn)',
      'hbyc': 'HBYC (3-15M)',
      'child': 'Child Health',
      'cbac': 'CBAC (NCD 30+)',
      'ncd': 'NCD Register',
      'idsp': 'IDSP / Disease',
      'birthdeath': 'Birth & Death',
      'claim': 'JSY/JSSK Claim',
    };
    return labels[registerType] ?? registerType;
  }

  /// Emoji icon for the register type
  String get icon {
    const icons = {
      'village': '🏘️',
      'ec': '👪',
      'anc': '🤰',
      'delivery': '🍼',
      'hbnc': '🏠',
      'hbyc': '👶',
      'child': '🧒',
      'cbac': '🩺',
      'ncd': '❤️',
      'idsp': '🦟',
      'birthdeath': '📋',
      'claim': '💰',
    };
    return icons[registerType] ?? '📒';
  }

  /// Count how many modules were filled
  int get filledModuleCount => moduleData.length;

  /// Count total fields filled across all modules
  int get totalFieldsFilled =>
      moduleData.values.fold(0, (sum, fields) => sum + fields.length);

  /// Count warning fields across all modules
  int get warningFieldCount => moduleData.values.fold(
        0,
        (sum, fields) =>
            sum + fields.values.where((v) => v.contains('⚠️')).length,
      );
}
