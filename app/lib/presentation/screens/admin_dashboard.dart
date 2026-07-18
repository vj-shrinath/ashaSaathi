import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/activity_log.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/backend_api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Dashboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('System Overview & Analytics',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'ASHA ACTIVITY'),
            Tab(text: 'DOCTOR ACTIVITY'),
            Tab(text: 'ALL LOGS'),
            Tab(text: 'DEVICE SYNC'),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(),
          _ActivityTab(userRole: 'asha', title: 'ASHA Worker Activity'),
          _ActivityTab(userRole: 'doctor', title: 'Doctor Activity'),
          _AllActivityLogsTab(),
          const _DeviceSyncTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERVIEW TAB
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: FirebaseService.getDashboardStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Cards
            _SummaryCard(
              label: 'Total Patients',
              value: stats['totalPatients']?.toString() ?? '0',
              color: const Color(0xFF1B5E20),
              icon: Icons.people_rounded,
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              label: 'Urgent Cases',
              value: stats['patientsByRisk']?['Red']?.toString() ?? '0',
              color: Colors.red,
              icon: Icons.emergency_rounded,
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              label: 'Active Visits',
              value: stats['activeVisits']?.toString() ?? '0',
              color: const Color(0xFF0277BD),
              icon: Icons.play_circle_rounded,
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              label: 'Pending Reviews',
              value: stats['pendingReviews']?.toString() ?? '0',
              color: Colors.orange,
              icon: Icons.pending_rounded,
            ),
            const SizedBox(height: 24),

            // Risk Distribution
            Text('Risk Distribution',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _RiskStatCard(
                    count: stats['patientsByRisk']?['Red'] ?? 0,
                    label: 'Critical',
                    color: Colors.red,
                    icon: Icons.emergency_rounded),
                const SizedBox(width: 8),
                _RiskStatCard(
                    count: stats['patientsByRisk']?['Orange'] ?? 0,
                    label: 'Urgent',
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded),
                const SizedBox(width: 8),
                _RiskStatCard(
                    count: stats['patientsByRisk']?['Yellow'] ?? 0,
                    label: 'Monitor',
                    color: Colors.amber[700]!,
                    icon: Icons.info_outline_rounded),
                const SizedBox(width: 8),
                _RiskStatCard(
                    count: stats['patientsByRisk']?['Green'] ?? 0,
                    label: 'Stable',
                    color: Colors.green,
                    icon: Icons.check_circle_outline_rounded),
              ],
            ),
            const SizedBox(height: 24),

            // Reports by Risk
            Text('Triage Reports by Risk',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _RiskStatCard(
                    count: stats['reportsByRisk']?['Red'] ?? 0,
                    label: 'Critical',
                    color: Colors.red,
                    icon: Icons.analytics_rounded),
                const SizedBox(width: 8),
                _RiskStatCard(
                    count: stats['reportsByRisk']?['Orange'] ?? 0,
                    label: 'Urgent',
                    color: Colors.orange,
                    icon: Icons.analytics_rounded),
                const SizedBox(width: 8),
                _RiskStatCard(
                    count: stats['reportsByRisk']?['Yellow'] ?? 0,
                    label: 'Monitor',
                    color: Colors.amber[700]!,
                    icon: Icons.analytics_rounded),
                const SizedBox(width: 8),
                _RiskStatCard(
                    count: stats['reportsByRisk']?['Green'] ?? 0,
                    label: 'Stable',
                    color: Colors.green,
                    icon: Icons.analytics_rounded),
              ],
            ),
            const SizedBox(height: 24),

            // Prescription Stats
            Text('Prescription Stats',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _RiskStatCard(
                    count: stats['totalPrescriptions'] ?? 0,
                    label: 'Total',
                    color: Colors.deepPurple,
                    icon: Icons.medication_rounded),
                const SizedBox(width: 8),
                _RiskStatCard(
                    count: stats['activePrescriptions'] ?? 0,
                    label: 'Active',
                    color: Colors.green,
                    icon: Icons.medication_rounded),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY TAB (ROLE-SPECIFIC)
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityTab extends StatelessWidget {
  final String userRole;
  final String title;

  const _ActivityTab({required this.userRole, required this.title});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityLog>>(
      stream: FirebaseService.watchActivityLogs(userRole: userRole, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return _EmptyState(
            icon: Icons.history_rounded,
            title: 'No Activity Yet',
            subtitle: '$title will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _ActivityLogCard(log: log);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL ACTIVITY LOGS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AllActivityLogsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF6A1B9A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF6A1B9A),
            tabs: [
              Tab(text: 'ALL'),
              Tab(text: 'ASHA'),
              Tab(text: 'DOCTOR'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ActivityTab(userRole: '', title: 'All Activity'),
                _ActivityTab(userRole: 'asha', title: 'ASHA Activity'),
                _ActivityTab(userRole: 'doctor', title: 'Doctor Activity'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY LOG CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityLogCard extends StatelessWidget {
  final ActivityLog log;

  const _ActivityLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
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
        title: Text(log.description, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(log.userRole).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    log.userRole.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(log.userRole)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(log.userName, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const Spacer(),
                Text(log.formattedTime, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () => _showLogDetail(context, log),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'asha':
        return const Color(0xFF2E7D32);
      case 'doctor':
        return const Color(0xFF0277BD);
      case 'admin':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }

  void _showLogDetail(BuildContext context, ActivityLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
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

                // Activity Type Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: log.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(log.icon, color: log.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.type.displayName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(log.formattedTime, style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // User Info
                _buildDetailRow('User', log.userName),
                _buildDetailRow('Role', log.userRole.toUpperCase()),
                if (log.patientId != null) _buildDetailRow('Patient ID', log.patientId!),
                if (log.visitId != null) _buildDetailRow('Visit ID', log.visitId!),

                const SizedBox(height: 16),
                Text('Description', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(log.description, style: TextStyle(color: Colors.grey[700])),

                if (log.metadata.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Metadata', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...log.metadata.entries.map((e) => _buildDetailRow(e.key, e.value.toString())),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey[800]))),
        ],
      ),
    );
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
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RISK STAT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RiskStatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _RiskStatCard({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text('$count',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Device Sync Tab — Generate one-time Sync PINs for ASHA workers
// ─────────────────────────────────────────────────────────────
class _DeviceSyncTab extends StatefulWidget {
  const _DeviceSyncTab();

  @override
  State<_DeviceSyncTab> createState() => _DeviceSyncTabState();
}

class _DeviceSyncTabState extends State<_DeviceSyncTab> {
  final _phoneController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedPin;
  String? _error;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _generateSyncCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _error = 'Enter valid 10-digit phone number');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedPin = null;
      _expiresAt = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _error = 'Admin session expired. Please re-login.';
          _isGenerating = false;
        });
        return;
      }

      final pin = await BackendApiService.generateSyncToken(
        phone: phone,
        adminToken: session.accessToken,
      );

      setState(() {
        _generatedPin = pin;
        _expiresAt = DateTime.now().add(const Duration(minutes: 10));
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sync_rounded, color: Colors.amber, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device Sync Manager',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Generate temporary codes for ASHA workers to transfer their account to a new phone.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'ASHA Worker Phone Number',
                      hintText: 'Enter 10-digit mobile number',
                      counterText: '',
                      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF6A1B9A)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _isGenerating
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                      : FilledButton.icon(
                          onPressed: _generateSyncCode,
                          icon: const Icon(Icons.vpn_key_rounded),
                          label: const Text('Generate Sync Code'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                ],
              ),
            ),
          ),
          // Generated PIN display
          if (_generatedPin != null) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 6,
              color: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Sync Code Generated',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _generatedPin!,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_expiresAt != null)
                      Text(
                        'Expires at ${_expiresAt!.hour.toString().padLeft(2, '0')}:${_expiresAt!.minute.toString().padLeft(2, '0')} (10 minutes)',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tell this code to the ASHA worker verbally.\nThey will enter it on their new phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}