import 'message_model.dart';
import 'patient_model.dart';

/// The structured doctor register generated after every analyzed ASHA voice note.
/// It deliberately keeps uncertain values blank instead of inventing clinical data.
class DoctorSheet {
  final String patientName;
  final String fatherName;
  final String age;
  final String sex;
  final String village;
  final String district;
  final String ashaName;
  final String date;
  final String chiefComplaint;
  final String riskCategory;
  final String protocol;
  final List<String> dangerSigns;
  final Map<String, dynamic> vitals;
  final String aiRecommendation;
  final String followUp;
  final String transcript;
  final bool isNewborn;

  const DoctorSheet({
    required this.patientName,
    required this.fatherName,
    required this.age,
    required this.sex,
    required this.village,
    required this.district,
    required this.ashaName,
    required this.date,
    required this.chiefComplaint,
    required this.riskCategory,
    required this.protocol,
    required this.dangerSigns,
    required this.vitals,
    required this.aiRecommendation,
    required this.followUp,
    required this.transcript,
    required this.isNewborn,
  });

  factory DoctorSheet.fromReport({
    required Patient? patient,
    required TriageResult result,
    required String transcript,
    required String ashaName,
    required DateTime createdAt,
  }) {
    final isNewborn = (patient?.age ?? 0) <= 1 ||
        result.symptoms.any((s) => s.toLowerCase().contains('newborn') || s.toLowerCase().contains('neonat')) ||
        transcript.toLowerCase().contains('newborn');
    final dangerSigns = <String>[
      ...result.symptoms,
      if (result.emergencyRequired) 'Emergency signs detected',
    ];
    var newbornAge = isNewborn ? '${patient?.age ?? 0} day(s)' : '${patient?.age ?? '—'} year(s)';
    final dayMatch = RegExp(r'(\d+)\s*(?:day|days|din)', caseSensitive: false).firstMatch(transcript);
    if (isNewborn && dayMatch != null) newbornAge = '${dayMatch.group(1)} days (Newborn — 0–28 days)';
    return DoctorSheet(
      patientName: patient?.name ?? 'Baby / Patient',
      fatherName: '',
      age: newbornAge,
      sex: isNewborn ? 'Female / Male — confirm' : '—',
      village: patient?.village ?? '—',
      district: 'Washim',
      ashaName: ashaName,
      date: '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
      chiefComplaint: result.patientSummary,
      riskCategory: '${result.riskCategory} Risk',
      protocol: isNewborn ? 'NHM HBNC Guidelines 2014 — Neonatal Danger Signs' : 'NHM / PHC Triage Protocol',
      dangerSigns: dangerSigns.isEmpty ? ['No danger sign extracted'] : dangerSigns,
      vitals: result.vitals,
      aiRecommendation: result.suggestedAction,
      followUp: result.followUpTime,
      transcript: transcript,
      isNewborn: isNewborn,
    );
  }
}
