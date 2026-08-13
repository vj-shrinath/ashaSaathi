import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/models/doctor_sheet.dart';
import '../../core/models/patient_model.dart';
import '../../core/services/firebase_service.dart';

/// Full PHC OPD register based on the HTML live-demo blueprint.
/// Green/blue values are AI/ASHA supplied; white fields are for doctor/ANM entry.
class DoctorSheetScreen extends StatefulWidget {
  final String patientId;

  const DoctorSheetScreen({super.key, required this.patientId});

  @override
  State<DoctorSheetScreen> createState() => _DoctorSheetScreenState();
}

class _DoctorSheetScreenState extends State<DoctorSheetScreen> {
  DoctorSheet? _sheet;
  TriageReport? _report;
  bool _loading = true;
  bool _saving = false;
  final Map<String, String> _values = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        FirebaseService.getPatient(widget.patientId),
        FirebaseService.getTriageReportsForPatient(widget.patientId),
      ]);
      final patient = results[0] as Patient?;
      final reports = results[1] as List<TriageReport>;
      if (!mounted) return;
      if (reports.isNotEmpty) {
        final report = reports.first;
        final sheet = DoctorSheet.fromReport(
          patient: patient,
          result: report.triageResult,
          transcript: report.transcript,
          ashaName: report.ashaName,
          createdAt: report.createdAt,
        );
        _report = report;
        _sheet = sheet;
        _seedValues(sheet);
        if (report.doctorSheet != null) {
          _values.addAll(report.doctorSheet!.map((key, value) => MapEntry(key, value.toString())));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _seedValues(DoctorSheet s) {
    _values.addAll({
      'OPD Serial No.': '',
      'Date': s.date,
      'Visit Type': 'New Patient / Naya',
      'Time': TimeOfDay.now().format(context),
      'Full Name': s.patientName,
      "Father's / Husband's Name": s.fatherName,
      'Age': s.age,
      'Gender': s.sex,
      'Caste Category': 'General',
      'Religion': 'Hindu',
      'Address / Village': s.village,
      'Taluka': 'Manora',
      'District': s.district,
      'Mobile No.': '',
      'Aadhar Last 4': '',
      'Occupation': '—',
      'BPL Card': '—',
      'ASHA Worker': s.ashaName,
      'Sub-Centre': '',
      'AWC No.': '',
      'Ayushman Bharat': 'Not Known',
      'MJPJAY': 'Not Enrolled',
      'JSY': s.isNewborn ? 'N/A' : 'Not Registered',
      'RCH / Mother-Child ID': '',
      'HMIS Patient ID': '',
      'Jan Aushadhi Card': '—',
      'Chief Complaint': s.chiefComplaint,
      'Duration': '',
      'Case Category': s.riskCategory,
      'Past Medical History': '',
      'Current Medications': '',
      'Allergies': '',
      'Surgery Before': 'No',
      'AI Risk Level': s.riskCategory,
      'NHM Protocol Applied': s.protocol,
      'AI Recommended Action': s.aiRecommendation,
      'General Condition': s.riskCategory.contains('Red') ? 'Critical / Gambhir' : 'Needs doctor examination',
      'Systemic Examination Findings': '',
      'Provisional Diagnosis': '',
      'Differential Diagnosis': '',
      'CBC': 'Ordered',
      'Blood Sugar': 'Ordered',
      'Urine R/E': 'Ordered',
      'Malaria RDT': 'Not required',
      'HIV / VDRL': 'Not required',
      'Blood Group': 'Not done',
      'USG': 'Not required',
      'ECG': 'Not required',
      'X-Ray': 'Not required',
      'Sputum / TB': 'Not required',
      'IV Fluids': '',
      'Injections': '',
      'Free Medicines Given': 'Prescription only',
      'Discharge Status': s.riskCategory.contains('Red') ? 'Referred — 108 Ambulance' : 'OPD — Sent Home',
      'Referred To': s.riskCategory.contains('Red') ? 'District Hospital Washim' : 'Not Referred',
      'Referral Reason': s.riskCategory.contains('Red') ? s.aiRecommendation : '',
      'Transport': s.riskCategory.contains('Red') ? '108 Ambulance' : 'N/A',
      'Referral Slip No.': '',
      'Referral Note': s.aiRecommendation,
      'Follow-up Date': '',
      'Next Visit Type': s.isNewborn ? 'General Follow-up' : 'General Follow-up',
      "Doctor's Notes": '',
      'Doctor Signature': '',
      'ASHA Signature': s.ashaName,
      'Patient / Guardian Signature': '',
    });
    for (final entry in s.vitals.entries) {
      _values['Vital: ${entry.key}'] = entry.value.toString();
    }
    if (s.isNewborn) {
      _values.addAll({
        'Child Age': s.age,
        'Birth Weight': _vital(s, ['birth weight', 'birth_weight']),
        'Current Weight': _vital(s, ['weight', 'current weight']),
        'Birth Type': _vital(s, ['birth place', 'birth type']),
        'Breastfeeding': _vital(s, ['feeding', 'breastfeeding']),
        'Immunization Status': 'Not assessed',
        'Vitamin A': 'N/A',
        'SAM/MAM Status': 'Not Assessed',
        'MUAC': '',
        'HBNC Visit No.': _hbncVisit(s.age),
      });
    }
  }

  String _vital(DoctorSheet s, List<String> names) {
    for (final entry in s.vitals.entries) {
      if (names.any((name) => entry.key.toLowerCase().contains(name))) return entry.value.toString();
    }
    return '';
  }

  String _hbncVisit(String age) {
    final match = RegExp(r'(\d+)').firstMatch(age);
    final days = int.tryParse(match?.group(1) ?? '0') ?? 0;
    if (days <= 1) return 'Day 1';
    if (days <= 3) return 'Day 3';
    if (days <= 7) return 'Day 7';
    if (days <= 14) return 'Day 14';
    if (days <= 21) return 'Day 21';
    if (days <= 28) return 'Day 28';
    return 'N/A';
  }

  String _get(String key) => _values[key] ?? '';
  void _set(String key, String value) => _values[key] = value;

  Future<void> _save() async {
    if (_report == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseService.saveDoctorSheet(_report!.id, _values);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor sheet saved')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sheet saved on screen. Run the doctor_sheet migration to enable cloud save.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    pw.ThemeData theme;
    try {
      final font = await PdfGoogleFonts.notoSansDevanagariRegular();
      final boldFont = await PdfGoogleFonts.notoSansDevanagariBold();
      theme = pw.ThemeData.withFont(base: font, bold: boldFont);
    } catch (_) {
      theme = pw.ThemeData.base();
    }

    final doc = pw.Document(theme: theme);
    String clean(String s) => s.replaceAll('—', '-').replaceAll('–', '-').replaceAll('·', '-').replaceAll('⚠️', '[WARN]').trim();

    final rows = _values.entries.where((e) => e.value.trim().isNotEmpty).map((e) => [clean(e.key), clean(e.value)]).toList();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        pw.Container(color: PdfColor.fromHex('#075E54'), padding: const pw.EdgeInsets.all(14), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('ASHA Saathi AI', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Vitholi PHC - OPD Patient Register / Doctor Sheet', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
          pw.SizedBox(height: 4), pw.Text(clean(_get('AI Risk Level')), style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
        ])),
        pw.SizedBox(height: 12),
        _pdfSection('PART A-C - Registration, patient details and schemes', rows.where((r) => ['OPD Serial No.', 'Date', 'Visit Type', 'Time', 'Full Name', 'Age', 'Gender', 'Address / Village', 'Taluka', 'District', 'ASHA Worker', 'Ayushman Bharat', 'MJPJAY', 'JSY', 'RCH / Mother-Child ID', 'HMIS Patient ID'].contains(r[0])).toList()),
        _pdfSection('PART D-H - AI complaint, vitals, child health and risk', rows.where((r) => r[0] == 'Chief Complaint' || r[0] == 'Duration' || r[0] == 'Case Category' || r[0].toString().startsWith('Vital:') || r[0] == 'Child Age' || r[0] == 'Birth Weight' || r[0] == 'Current Weight' || r[0] == 'Birth Type' || r[0] == 'Breastfeeding' || r[0] == 'HBNC Visit No.' || r[0] == 'AI Risk Level' || r[0] == 'NHM Protocol Applied' || r[0] == 'AI Recommended Action').toList()),
        _pdfSection('PART I-M - Examination, investigations, treatment, referral and follow-up', rows.where((r) => !['OPD Serial No.', 'Date', 'Visit Type', 'Time', 'Full Name', 'Age', 'Gender', 'Address / Village', 'Taluka', 'District', 'ASHA Worker', 'Ayushman Bharat', 'MJPJAY', 'JSY', 'RCH / Mother-Child ID', 'HMIS Patient ID', 'Chief Complaint', 'Duration', 'Case Category', 'AI Risk Level', 'NHM Protocol Applied', 'AI Recommended Action'].contains(r[0]) && !r[0].toString().startsWith('Vital:') && !['Child Age', 'Birth Weight', 'Current Weight', 'Birth Type', 'Breastfeeding', 'HBNC Visit No.'].contains(r[0])).toList()),
        pw.SizedBox(height: 12),
        pw.Text('Original ASHA voice transcript', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text(clean(_sheet?.transcript ?? ''), style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 20), pw.Text('Doctor signature: ____________________    ASHA signature: ____________________'),
      ],
    ));
    return doc.save();
  }

  pw.Widget _pdfSection(String title, List<List<String>> rows) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
    if (rows.isNotEmpty) pw.TableHelper.fromTextArray(headers: const ['Field', 'Value'], data: rows),
    pw.SizedBox(height: 10),
  ]);

  Future<void> _share() async {
    await _save();
    await Printing.sharePdf(bytes: await _buildPdf(), filename: 'doctor-sheet-${widget.patientId}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _sheet;
    if (s == null) return Scaffold(appBar: AppBar(title: const Text('Doctor Sheet')), body: const Center(child: Text('No analyzed voice report yet.')));
    return Scaffold(
      appBar: AppBar(title: const Text('PHC OPD Register — Doctor Sheet'), actions: [
        IconButton(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), tooltip: 'Save sheet'),
        IconButton(onPressed: _share, icon: const Icon(Icons.picture_as_pdf_rounded), tooltip: 'PDF / Send to ANM'),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(s),
        _section('PART A — PATIENT REGISTRATION / MAREEZ KI NOONDANI', const Color(0xFF1A4731), [
          _input('OPD Serial No.'), _auto('Date'), _input('Visit Type'), _auto('Time'),
        ]),
        _section('PART B — PATIENT DETAILS / RUGNACHI MAHITI', const Color(0xFF0C4A6E), [
          _auto('Full Name', wide: true), _input("Father's / Husband's Name", wide: true), _auto('Age'), _input('Gender'), _input('Caste Category'), _input('Religion'), _auto('Address / Village', wide: true), _auto('Taluka'), _auto('District'), _input('Mobile No.'), _input('Aadhar Last 4'), _input('Occupation'), _input('BPL Card'), _auto('ASHA Worker', wide: true), _input('Sub-Centre'), _input('AWC No.'),
        ]),
        _section('PART C — HEALTH SCHEME / AROGYA YOJANA', const Color(0xFF4A0E8F), [
          _input('Ayushman Bharat'), _input('MJPJAY'), _input('JSY'), _input('RCH / Mother-Child ID'), _input('HMIS Patient ID'), _input('Jan Aushadhi Card'),
        ]),
        _section('PART D — CHIEF COMPLAINT / MUKHY TAKRAR (AI AUTO-FILLED)', const Color(0xFF7B1E1E), [
          _auto('Chief Complaint', wide: true, multiline: true), _input('Duration'), _auto('Case Category'), _input('Past Medical History', wide: true), _input('Current Medications', wide: true), _input('Allergies'), _input('Surgery Before'),
        ]),
        _section('PART E — VITAL SIGNS / PRANIK CHINHE', const Color(0xFF1A3A1A), [
          ...s.vitals.keys.map((key) => _auto('Vital: $key')),
          _input('BP (Doctor check)'), _input('Pulse / Nadi'), _input('Temperature'), _input('SpO2 / Oxygen'), _input('Respiratory Rate'), _input('Weight'), _input('Height'), _input('Random Blood Sugar'),
        ]),
        _section('PART F — MATERNAL HEALTH / MATRUTVA (ANC/PNC — IF APPLICABLE)', const Color(0xFF880E6A), [
          _input('Gravida (G)'), _input('Para (P)'), _input('LMP'), _input('EDD'), _input('ANC Visit No.'), _input('Haemoglobin'), _input('Urine Albumin'), _input('Urine Sugar'), _input('Foetal Heart Rate'), _input('Foetal Presentation'), _input('IFA Tablets Given'), _input('TT Immunization'), _input('Calcium Tablets'), _input('JSY Registration'),
        ]),
        if (s.isNewborn) _section('PART G — CHILD HEALTH / BALASVASTHYA (HBNC/UIP)', const Color(0xFF1565C0), [
          _auto('Child Age'), _auto('Birth Weight'), _auto('Current Weight'), _auto('Birth Type'), _auto('Breastfeeding'), _input('Immunization Status'), _input('Vitamin A'), _input('SAM/MAM Status'), _input('MUAC'), _input('HBNC Visit No.'),
        ]),
        _section('PART H — AI RISK ASSESSMENT / AI JOKHIM MULYANKAN', const Color(0xFF0D2818), [
          _auto('AI Risk Level'), _auto('NHM Protocol Applied'), _auto('AI Recommended Action', wide: true, multiline: true),
        ]),
        _section('PART I — DOCTOR EXAMINATION / DOCTOR TAPASNI', const Color(0xFF333333), [
          _input('General Condition'), _input('Systemic Examination Findings', wide: true, multiline: true), _input('Provisional Diagnosis', wide: true), _input('Differential Diagnosis', wide: true),
        ]),
        _section('PART J — INVESTIGATIONS / PRAYOGSHALA TAPASNI', const Color(0xFF5C2D00), [
          _input('CBC'), _input('Blood Sugar'), _input('Urine R/E'), _input('Malaria RDT'), _input('HIV / VDRL'), _input('Blood Group'), _input('USG'), _input('ECG'), _input('X-Ray'), _input('Sputum / TB'),
        ]),
        _section('PART K — TREATMENT / UPCHAR', const Color(0xFF1B4332), [
          _input('Medicines Prescribed', wide: true, multiline: true), _input('IV Fluids', wide: true), _input('Injections', wide: true), _input('Free Medicines Given'), _input('Discharge Status'),
        ]),
        _section('PART L — REFERRAL DETAILS / SANDARBHAN MAHITI', const Color(0xFF1A0A3C), [
          _input('Referred To'), _input('Referral Reason'), _input('Transport'), _input('Referral Slip No.'), _input('Referral Note', wide: true, multiline: true),
        ]),
        _section('PART M — COUNSELLING & FOLLOW-UP / MARGADARSHAN', const Color(0xFF0D2818), [
          _checks(['Danger signs explained', 'Diet counselling', 'Medicine compliance', 'Family planning advice', 'Breastfeeding counselling', 'Sanitation awareness', 'ASHA follow-up instructions', 'Govt scheme enrollment']), _input('Follow-up Date'), _input('Next Visit Type'), _input("Doctor's Notes", wide: true, multiline: true),
        ]),
        _section('PART N — SIGNATURES / SASHIANKITE', const Color(0xFF222222), [
          _input('Doctor Signature'), _auto('ASHA Signature'), _input('Patient / Guardian Signature'),
        ]),
        Card(color: const Color(0xFFEEF8F2), child: const Padding(padding: EdgeInsets.all(12), child: Text('AI ne voice note se highlighted fields fill kiye hain. ⚠️ fields doctor/ANM ko verify karne hain; baaki fields manually complete karein.'))),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Save Sheet'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: _share, icon: const Icon(Icons.send), label: const Text('PDF / ANM ko Share')))]),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _header(DoctorSheet s) => Container(width: double.infinity, padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFF075E54), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [const Text('GOVERNMENT OF MAHARASHTRA · NHM · PRIMARY HEALTH CENTRE', style: TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), const Text('Vitholi PHC — OPD Patient Register', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text('Manora Taluka · Washim District · Maharashtra', style: const TextStyle(color: Colors.white70, fontSize: 10)), const SizedBox(height: 8), Text('🤖 AUTO-FILLED BY ASHA SAATHI AI  •  ${s.riskCategory}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]));

  Widget _section(String title, Color color, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth > 560;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: children.map((child) {
                    final isWide = child is _WideField && child.wide;
                    return SizedBox(
                      width: twoColumns && !isWide
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth,
                      child: child,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _auto(String key, {bool wide = false, bool multiline = false}) => _field(key, true, wide: wide, multiline: multiline);
  Widget _input(String key, {bool wide = false, bool multiline = false}) => _field(key, false, wide: wide, multiline: multiline);

  Widget _field(String key, bool auto, {bool wide = false, bool multiline = false}) {
    final child = TextFormField(
      initialValue: _get(key),
      maxLines: multiline ? 4 : 1,
      onChanged: (value) => _set(key, value),
      style: const TextStyle(
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: key,
        labelStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        filled: true,
        fillColor: auto ? const Color(0xFFEAF7EF) : const Color(0xFFFAF8F3),
        suffixIcon: auto ? const Icon(Icons.auto_awesome, size: 16, color: Colors.green) : null,
      ),
    );
    return _WideField(wide: wide, child: child);
  }

  Widget _checks(List<String> labels) => _WideField(wide: true, child: Wrap(spacing: 10, runSpacing: 4, children: labels.map((label) => FilterChip(label: Text(label, style: const TextStyle(fontSize: 11)), selected: _get(label) == 'Yes', onSelected: (selected) => setState(() => _set(label, selected ? 'Yes' : 'No')))).toList()));
}

class _WideField extends StatelessWidget {
  final Widget child;
  final bool wide;
  const _WideField({required this.child, this.wide = false});
  @override
  Widget build(BuildContext context) => child;
}
