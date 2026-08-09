import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/patient_model.dart';
import '../../core/services/firebase_service.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final String patientId;

  const DoctorPatientDetailScreen({super.key, required this.patientId});

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  Patient? _patient;
  TriageReport? _latestReport;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      FirebaseService.getPatient(widget.patientId),
      FirebaseService.getTriageReportsForPatient(widget.patientId),
    ]);

    if (!mounted) return;
    final reports = results[1] as List<TriageReport>;
    setState(() {
      _patient = results[0] as Patient?;
      _latestReport = reports.isNotEmpty ? reports.first : null;
      _isLoading = false;
    });
  }

  Future<String?> _resolveChatVisitId() async {
    final reportVisitId = _latestReport?.visitId;
    if (reportVisitId != null && reportVisitId.isNotEmpty) {
      return reportVisitId;
    }
    return FirebaseService.getLatestVisitIdForPatient(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final patient = _patient;
    final report = _latestReport;

    if (patient == null && report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Overview')),
        body: const Center(
          child: Text('Patient not found'),
        ),
      );
    }

    final displayName = patient?.name.isNotEmpty == true
        ? patient!.name
        : report?.patientName ?? 'Patient Overview';
    final displayAge = patient?.age;
    final displayVillage = patient?.village;
    final displayRisk = patient?.riskCategory ??
        report?.triageResult.riskCategory ??
        'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.medication),
            onPressed: () async {
              final visitId = await _resolveChatVisitId();
              if (!context.mounted || visitId == null) return;
              context.push('/prescription/${widget.patientId}/$visitId');
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () async {
              final visitId = await _resolveChatVisitId();
              if (!context.mounted || visitId == null) return;
              context.push('/chat/${widget.patientId}/$visitId');
            },
          ),
          IconButton(
            icon: const Icon(Icons.assignment_rounded),
            tooltip: 'Open doctor sheet',
            onPressed: () => context.push('/doctor-sheet/${widget.patientId}'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(
              patientName: displayName,
              age: displayAge,
              village: displayVillage,
              riskCategory: displayRisk,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HealthSection(
                    patientName: displayName,
                    age: displayAge,
                    village: displayVillage,
                    riskCategory: displayRisk,
                    lastMessage: patient?.lastMessage,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Latest ASHA Summary',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<TriageReport>>(
                    stream: FirebaseService.watchTriageReportsForPatient(widget.patientId),
                    builder: (context, snapshot) {
                      final reports = snapshot.data ?? [];
                      final latest = reports.isNotEmpty ? reports.first : report;
                      if (latest == null) {
                        return const Text('No triage summary yet.');
                      }
                      return _SummaryBubble(report: latest);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/doctor-sheet/${widget.patientId}'),
                      icon: const Icon(Icons.assignment_rounded),
                      label: const Text('Open Auto-filled Doctor Sheet'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            context.push('/dashboard/doctor');
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Dashboard'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String patientName;
  final int? age;
  final String? village;
  final String riskCategory;

  const _Header({
    required this.patientName,
    required this.age,
    required this.village,
    required this.riskCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFE8F4FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patientName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${age != null ? '$age y' : 'Age unknown'} • ${village ?? 'Village unknown'}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Risk: $riskCategory',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _HealthSection extends StatelessWidget {
  final String patientName;
  final int? age;
  final String? village;
  final String riskCategory;
  final String? lastMessage;

  const _HealthSection({
    required this.patientName,
    required this.age,
    required this.village,
    required this.riskCategory,
    required this.lastMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Health Dashboard',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Name: $patientName'),
            Text('Age: ${age ?? 'Unknown'}'),
            Text('Village: ${village ?? 'Unknown'}'),
            Text('Current Risk: $riskCategory'),
            if (lastMessage != null) Text('Latest Note: $lastMessage'),
          ],
        ),
      ),
    );
  }
}

class _SummaryBubble extends StatelessWidget {
  final TriageReport report;

  const _SummaryBubble({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.triageResult.severity,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(report.triageResult.patientSummary),
            const SizedBox(height: 8),
            Text(
              'Risk: ${report.triageResult.riskCategory} • Score ${report.triageResult.riskScore}/10',
            ),
          ],
        ),
      ),
    );
  }
}
