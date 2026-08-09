import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/patient_model.dart';
import '../../core/services/firebase_service.dart';

class DoctorPatientListScreen extends StatefulWidget {
  const DoctorPatientListScreen({super.key});

  @override
  State<DoctorPatientListScreen> createState() => _DoctorPatientListScreenState();
}

class _DoctorPatientListScreenState extends State<DoctorPatientListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _doctorId;
  String? _phcId;
  Set<String> _scopedAshaIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDoctorScope();
  }

  Future<void> _loadDoctorScope() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _doctorId = user.id;

      final docProfile = await Supabase.instance.client
          .from('user_profiles')
          .select('phc_id')
          .eq('id', user.id)
          .maybeSingle();

      final phcId = docProfile != null ? docProfile['phc_id'] as String? : null;
      _phcId = phcId;

      final Set<String> ashaSet = {};

      if (phcId != null) {
        final ashaRows = await Supabase.instance.client
            .from('user_profiles')
            .select('id')
            .eq('role', 'asha')
            .eq('phc_id', phcId);
        ashaSet.addAll((ashaRows as List).map((r) => r['id'] as String));
      }

      final directAshaRows = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('role', 'asha')
          .eq('doctor_id', user.id);
      ashaSet.addAll((directAshaRows as List).map((r) => r['id'] as String));

      if (mounted) {
        setState(() {
          _scopedAshaIds = ashaSet;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading doctor scope: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F4FD),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0277BD)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FD),
      appBar: AppBar(
        title: const Text('Select Patient for Prescription'),
        backgroundColor: const Color(0xFF0277BD),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Urgent (Red/Orange)'),
            Tab(text: 'Monitor (Yellow)'),
            Tab(text: 'All Patients'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PatientListTab(
            ashaIds: _scopedAshaIds,
            filter: _DashboardFilter.urgent,
          ),
          _PatientListTab(
            ashaIds: _scopedAshaIds,
            filter: _DashboardFilter.monitor,
          ),
          _PatientListTab(
            ashaIds: _scopedAshaIds,
            filter: _DashboardFilter.allPatients,
          ),
        ],
      ),
    );
  }
}

enum _DashboardFilter {
  urgent('Urgent Patients'),
  monitor('Monitor Patients'),
  allPatients('All Patients');

  const _DashboardFilter(this.title);
  final String title;
}

class _PatientListTab extends StatelessWidget {
  final Set<String> ashaIds;
  final _DashboardFilter filter;

  const _PatientListTab({
    required this.ashaIds,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TriageReport>>(
      stream: FirebaseService.watchTriageReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawReports = snapshot.data ?? [];
        final reports = rawReports.where((r) => ashaIds.contains(r.ashaId)).toList();
        final latestByPatient = <String, TriageReport>{};
        for (final report in reports) {
          latestByPatient.putIfAbsent(report.patientId, () => report);
        }

        var items = latestByPatient.values.toList();
        switch (filter) {
          case _DashboardFilter.urgent:
            items = items.where((r) =>
                r.triageResult.riskCategory == 'Red' ||
                r.triageResult.riskCategory == 'Orange').toList();
            break;
          case _DashboardFilter.monitor:
            items = items.where((r) => r.triageResult.riskCategory == 'Yellow').toList();
            break;
          case _DashboardFilter.allPatients:
            break;
        }

        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No Patients Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                SizedBox(height: 8),
                Text('No patients match this filter', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) => _PatientListTile(report: items[index]),
        );
      },
    );
  }
}

class _PatientListTile extends StatelessWidget {
  final TriageReport report;

  const _PatientListTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (report.triageResult.riskCategory) {
      'Red' => Colors.red,
      'Orange' => Colors.orange,
      'Yellow' => Colors.amber[700]!,
      _ => Colors.green,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: riskColor.withValues(alpha: 0.15),
          child: Text(
            report.patientName.isNotEmpty ? report.patientName[0].toUpperCase() : '?',
            style: TextStyle(color: riskColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(report.patientName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ASHA: ${report.ashaName} • ${report.triageResult.patientSummary}',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.triageResult.riskCategory,
                    style: TextStyle(
                        color: riskColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${report.triageResult.riskScore}/10',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: FilledButton(
          onPressed: () {
            final visitId = report.visitId.isNotEmpty ? report.visitId : null;
            if (visitId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No visit ID available for this patient')),
              );
              return;
            }
            context.push('/prescription/${report.patientId}/$visitId');
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0277BD),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Prescribe'),
        ),
        onTap: () => context.push('/dashboard/doctor/patient/${report.patientId}'),
      ),
    );
  }
}