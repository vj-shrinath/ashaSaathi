import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/patient_model.dart';
import '../../core/models/prescription.dart';
import '../../core/models/activity_log.dart';
import '../../core/services/firebase_service.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  _DashboardFilter _selectedFilter = _DashboardFilter.urgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0277BD),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor Triage Dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Fast patient overview & actions',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/auth/login');
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _OverviewHeader(),
            const SizedBox(height: 16),
            _SummaryGrid(
              selectedFilter: _selectedFilter,
              onSelected: (filter) => setState(() => _selectedFilter = filter),
            ),
            const SizedBox(height: 16),
            _SectionPills(
              selectedFilter: _selectedFilter,
              onSelected: (filter) => setState(() => _selectedFilter = filter),
            ),
            const SizedBox(height: 16),
            Text(_selectedFilter.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 420,
              child: _PatientFeedPanel(filter: _selectedFilter),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DashboardFilter {
  urgent('Urgent Patients'),
  monitor('Monitor Patients'),
  stable('Stable Patients'),
  allPatients('All Patients'),
  pending('Pending Reviews'),
  prescriptions('Prescriptions'),
  activity('Activity Feed');

  const _DashboardFilter(this.title);
  final String title;
}

class _OverviewHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0277BD), Color(0xFF64B5F6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick triage overview',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Scan patients, open a detail view, and act without leaving the dashboard.',
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final _DashboardFilter selectedFilter;
  final ValueChanged<_DashboardFilter> onSelected;

  const _SummaryGrid({
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TriageReport>>(
      stream: FirebaseService.watchTriageReports(),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? [];
        final latestByPatient = <String, TriageReport>{};
        for (final r in reports) {
          latestByPatient.putIfAbsent(r.patientId, () => r);
        }
        final unique = latestByPatient.values.toList();
        final red = unique.where((r) => r.triageResult.riskCategory == 'Red').length;
        final orange = unique.where((r) => r.triageResult.riskCategory == 'Orange').length;
        final yellow = unique.where((r) => r.triageResult.riskCategory == 'Yellow').length;
        final green = unique.where((r) => r.triageResult.riskCategory == 'Green').length;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _MiniStatCard(
              label: 'Urgent',
              value: '${red + orange}',
              color: Colors.red,
              icon: Icons.emergency_rounded,
              selected: selectedFilter == _DashboardFilter.urgent,
              onTap: () => onSelected(_DashboardFilter.urgent),
            ),
            _MiniStatCard(
              label: 'Monitor',
              value: '$yellow',
              color: Colors.amber[700]!,
              icon: Icons.monitor_heart_rounded,
              selected: selectedFilter == _DashboardFilter.monitor,
              onTap: () => onSelected(_DashboardFilter.monitor),
            ),
            _MiniStatCard(
              label: 'Stable',
              value: '$green',
              color: Colors.green,
              icon: Icons.check_circle_rounded,
              selected: selectedFilter == _DashboardFilter.stable,
              onTap: () => onSelected(_DashboardFilter.stable),
            ),
            _MiniStatCard(
              label: 'Patients',
              value: '${unique.length}',
              color: const Color(0xFF0277BD),
              icon: Icons.people_alt_rounded,
              selected: selectedFilter == _DashboardFilter.allPatients,
              onTap: () => onSelected(_DashboardFilter.allPatients),
            ),
          ],
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.18),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPills extends StatelessWidget {
  final _DashboardFilter selectedFilter;
  final ValueChanged<_DashboardFilter> onSelected;
  const _SectionPills({
    required this.selectedFilter,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _pill('Triage', Icons.analytics_rounded, const Color(0xFF0277BD), _DashboardFilter.allPatients),
        _pill('Urgent', Icons.emergency_rounded, Colors.red, _DashboardFilter.urgent),
        _pill('Monitor', Icons.monitor_heart_rounded, Colors.amber[700]!, _DashboardFilter.monitor),
        _pill('Stable', Icons.check_circle_rounded, Colors.green, _DashboardFilter.stable),
        _pill('Pending', Icons.pending_actions_rounded, Colors.orange, _DashboardFilter.pending),
        _pill('Prescriptions', Icons.medication_rounded, Colors.deepPurple, _DashboardFilter.prescriptions),
        _pill('Activity', Icons.history_rounded, const Color(0xFF2E7D32), _DashboardFilter.activity),
      ],
    );
  }

  Widget _pill(String label, IconData icon, Color color, _DashboardFilter filter) {
    final selected = selectedFilter == filter;
    return GestureDetector(
      onTap: () => onSelected(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFeedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityLog>>(
      stream: FirebaseService.watchActivityLogs(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return const _EmptyState(
            icon: Icons.history_rounded,
            title: 'No Activity Yet',
            subtitle: 'ASHA, doctor, and admin actions will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: log.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(log.icon, color: log.color, size: 20),
                ),
                title: Text(log.description,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '${log.userName} (${log.userRole.toUpperCase()}) • ${log.formattedTime}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              ),
            );
          },
        );
      },
    );
  }
}

class _PatientFeedPanel extends StatelessWidget {
  final _DashboardFilter filter;

  const _PatientFeedPanel({required this.filter});

  @override
  Widget build(BuildContext context) {
    if (filter == _DashboardFilter.pending) {
      return _PendingReviewTab();
    }
    if (filter == _DashboardFilter.prescriptions) {
      return _PrescriptionsTab();
    }
    if (filter == _DashboardFilter.activity) {
      return _ActivityFeedTab();
    }

    return StreamBuilder<List<TriageReport>>(
      stream: FirebaseService.watchTriageReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];
        final latestByPatient = <String, TriageReport>{};
        for (final report in reports) {
          latestByPatient.putIfAbsent(report.patientId, () => report);
        }

        var items = latestByPatient.values.toList();
        switch (filter) {
          case _DashboardFilter.urgent:
            items = items.where((r) => r.triageResult.riskCategory == 'Red' || r.triageResult.riskCategory == 'Orange').toList();
            break;
          case _DashboardFilter.monitor:
            items = items.where((r) => r.triageResult.riskCategory == 'Yellow').toList();
            break;
          case _DashboardFilter.stable:
            items = items.where((r) => r.triageResult.riskCategory == 'Green').toList();
            break;
          case _DashboardFilter.allPatients:
          case _DashboardFilter.pending:
          case _DashboardFilter.prescriptions:
          case _DashboardFilter.activity:
            break;
        }

        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No Patients Found',
            subtitle: 'Try another filter tile above.',
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => _PatientTriageTile(report: items[index]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIAGE REPORTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _TriageReportsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TriageReport>>(
      stream: FirebaseService.watchTriageReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const _EmptyState(
            icon: Icons.analytics_outlined,
            title: 'No Triage Reports',
            subtitle: 'ASHA worker visits will generate triage reports here',
          );
        }

        final latestByPatient = <String, TriageReport>{};
        for (final report in reports) {
          latestByPatient.putIfAbsent(report.patientId, () => report);
        }
        final grouped = latestByPatient.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final report = grouped[index];
            return _PatientTriageTile(report: report);
          },
        );
      },
    );
  }
}

class _PatientTriageTile extends StatelessWidget {
  final TriageReport report;

  const _PatientTriageTile({required this.report});

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
        subtitle: Text(
          '${report.ashaName} • ${report.triageResult.patientSummary}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                report.triageResult.riskCategory,
                style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                color: const Color(0xFF0277BD),
                tooltip: 'Open ASHA chat',
                onPressed: () {
                  final visitId = report.visitId.isNotEmpty ? report.visitId : null;
                  if (visitId == null) {
                    context.push('/dashboard/doctor/patient/${report.patientId}');
                    return;
                  }
                  context.push('/chat/${report.patientId}/$visitId');
                },
              ),
            ],
          ),
        onTap: () => context.push('/dashboard/doctor/patient/${report.patientId}'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING REVIEW TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PendingReviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TriageReport>>(
      stream: FirebaseService.watchTriageReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];
        final pending = reports.where((r) => !r.reviewedByDoctor).toList();

        if (pending.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            title: 'All Caught Up!',
            subtitle: 'No pending triage reports to review',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final report = pending[index];
            return _TriageReportCard(report: report, highlightPending: true);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRESCRIPTIONS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PrescriptionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prescription>>(
      stream: FirebaseService.watchPrescriptions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data ?? [];

        if (prescriptions.isEmpty) {
          return const _EmptyState(
            icon: Icons.medication_outlined,
            title: 'No Prescriptions',
            subtitle: 'Prescriptions will appear here after creating them',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: prescriptions.length,
          itemBuilder: (context, index) {
            final prescription = prescriptions[index];
            return _PrescriptionCard(prescription: prescription);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIAGE REPORT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TriageReportCard extends StatelessWidget {
  final TriageReport report;
  final bool highlightPending;

  const _TriageReportCard({
    required this.report,
    this.highlightPending = false,
  });

  Color get _riskColor {
    switch (report.triageResult.riskCategory) {
      case 'Red':
        return Colors.red;
      case 'Orange':
        return Colors.orange;
      case 'Yellow':
        return Colors.amber[700]!;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = !report.reviewedByDoctor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: highlightPending && isPending ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlightPending && isPending
            ? BorderSide(color: Colors.orange.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showReportDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Patient Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _riskColor.withValues(alpha: 0.15),
                    child: Text(
                      report.patientName.isNotEmpty
                          ? report.patientName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: _riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Patient Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                report.patientName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _riskColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _riskColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                report.triageResult.riskCategory,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _riskColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ASHA: ${report.ashaName} • ${_formatDate(report.createdAt)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),

                  // Status Icon
                  Column(
                    children: [
                      Icon(
                        report.reviewedByDoctor
                            ? Icons.check_circle
                            : Icons.pending,
                        color: report.reviewedByDoctor ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.reviewedByDoctor ? 'Reviewed' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          color: report.reviewedByDoctor ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Transcript Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mic_rounded, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text('Voice Transcript',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.transcript,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Triage Details
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(
                    icon: Icons.favorite_rounded,
                    label: 'Severity: ${report.triageResult.severity}',
                    color: _riskColor,
                  ),
                  _DetailChip(
                    icon: Icons.score_rounded,
                    label: 'Risk Score: ${report.triageResult.riskScore}/10',
                    color: _riskColor,
                  ),
                  if (report.triageResult.doctorRequired)
                    _DetailChip(
                      icon: Icons.medical_services_rounded,
                      label: 'Doctor Required',
                      color: Colors.red,
                    ),
                  if (report.triageResult.emergencyRequired)
                    _DetailChip(
                      icon: Icons.emergency_rounded,
                      label: 'EMERGENCY',
                      color: Colors.red,
                    ),
                ],
              ),

              // Action Buttons
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _markReviewed(context),
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: const Text('Review'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0277BD),
                          side: const BorderSide(color: Color(0xFF0277BD)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _createPrescription(context),
                        icon: const Icon(Icons.medication_rounded, size: 18),
                        label: const Text('Prescribe'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0277BD),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showReportDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TriageDetailSheet(report: report),
    );
  }

  void _markReviewed(BuildContext context) async {
    await FirebaseService.markReportReviewed(report.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report marked as reviewed')),
      );
    }
  }

  void _createPrescription(BuildContext context) {
    context.push('/prescription/${report.patientId}/${report.visitId}');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIAGE DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _TriageDetailSheet extends StatelessWidget {
  final TriageReport report;

  const _TriageDetailSheet({required this.report});

  Color get _riskColor {
    switch (report.triageResult.riskCategory) {
      case 'Red':
        return Colors.red;
      case 'Orange':
        return Colors.orange;
      case 'Yellow':
        return Colors.amber[700]!;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _riskColor.withValues(alpha: 0.15),
                    child: Text(
                      report.patientName.isNotEmpty
                          ? report.patientName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: _riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.patientName,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _riskColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _riskColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '${report.triageResult.riskCategory} Risk',
                                style: TextStyle(
                                  color: _riskColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              report.reviewedByDoctor ? '✓ Reviewed' : '⏳ Pending',
                              style: TextStyle(
                                color: report.reviewedByDoctor
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Triage Details
              _buildDetailSection('Patient Summary', report.triageResult.patientSummary),
              _buildDetailSection('Symptoms', report.triageResult.symptoms.join(', ')),
              _buildDetailSection('Suggested Action', report.triageResult.suggestedAction),
              _buildDetailSection('Medical Notes', report.triageResult.medicalNotes),
              _buildDetailSection('Follow-up Time', report.triageResult.followUpTime),

              // Vitals
              if (report.triageResult.vitals.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Vitals', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: report.triageResult.vitals.entries.map((e) => Chip(
                    label: Text('${e.key}: ${e.value}'),
                    backgroundColor: Colors.grey[100],
                  )).toList(),
                ),
              ],

              const SizedBox(height: 24),

              // Full Transcript
              Text('Full Voice Transcript', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(report.transcript, style: const TextStyle(height: 1.5)),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (!report.reviewedByDoctor) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          FirebaseService.markReportReviewed(report.id);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark Reviewed'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/prescription/${report.patientId}/${report.visitId}');
                        },
                        icon: const Icon(Icons.medication),
                        label: const Text('Create Prescription'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 6),
          Text(content, style: TextStyle(color: Colors.grey[700], height: 1.4)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRESCRIPTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionCard({required this.prescription});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPrescriptionDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                    child: Text(
                      prescription.patientName.isNotEmpty
                          ? prescription.patientName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prescription.patientName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          'Dr. ${prescription.doctorName} • ${prescription.formattedDate}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: prescription.isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      prescription.status.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        color: prescription.isActive ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(prescription.diagnosis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prescription.medications.map((med) => Chip(
                  label: Text('${med.name} (${med.dosage})'),
                  avatar: Icon(_getMedIcon(med.type), size: 16),
                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMedIcon(MedicationType type) {
    switch (type) {
      case MedicationType.tablet:
        return Icons.medication;
      case MedicationType.capsule:
        return Icons.medication_outlined;
      case MedicationType.syrup:
        return Icons.local_drink;
      case MedicationType.injection:
        return Icons.vaccines;
      case MedicationType.drops:
        return Icons.opacity;
      case MedicationType.ointment:
        return Icons.healing;
      case MedicationType.inhaler:
        return Icons.air;
      default:
        return Icons.medication;
    }
  }

  void _showPrescriptionDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PrescriptionDetailSheet(prescription: prescription),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRESCRIPTION DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _PrescriptionDetailSheet extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionDetailSheet({required this.prescription});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                    child: Text(
                      prescription.patientName.isNotEmpty
                          ? prescription.patientName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prescription.patientName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Dr. ${prescription.doctorName}',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Diagnosis
              _buildSection('Diagnosis', prescription.diagnosis),

              // Medications
              if (prescription.medications.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Medications', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...prescription.medications.map((med) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(_getMedIcon(med.type), color: Colors.deepPurple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(med.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${med.dosage} • ${med.frequency} • ${med.duration}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              if (med.instructions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(med.instructions,
                                      style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],

              // Notes
              if (prescription.notes.isNotEmpty) _buildSection('Notes', prescription.notes),
              if (prescription.followUpInstructions.isNotEmpty)
                _buildSection('Follow-up Instructions', prescription.followUpInstructions),
              if (prescription.followUpDate != null)
                _buildSection('Follow-up Date', '${prescription.followUpDate!.day}/${prescription.followUpDate!.month}/${prescription.followUpDate!.year}'),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 6),
          Text(content, style: TextStyle(color: Colors.grey[700], height: 1.4)),
        ],
      ),
    );
  }

  IconData _getMedIcon(MedicationType type) {
    switch (type) {
      case MedicationType.tablet:
        return Icons.medication;
      case MedicationType.capsule:
        return Icons.medication_outlined;
      case MedicationType.syrup:
        return Icons.local_drink;
      case MedicationType.injection:
        return Icons.vaccines;
      case MedicationType.drops:
        return Icons.opacity;
      case MedicationType.ointment:
        return Icons.healing;
      case MedicationType.inhaler:
        return Icons.air;
      default:
        return Icons.medication;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
