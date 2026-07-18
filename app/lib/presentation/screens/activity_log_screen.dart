import 'package:flutter/material.dart';
import '../../core/models/activity_log.dart';
import '../../core/services/firebase_service.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRole = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        title: const Text('Activity Logs'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'ALL'),
            Tab(text: 'ASHA'),
            Tab(text: 'DOCTOR'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActivityLogTab(userRole: null),
          _ActivityLogTab(userRole: 'asha'),
          _ActivityLogTab(userRole: 'doctor'),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Logs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Roles'),
              leading: Radio<String>(
                value: 'all',
                groupValue: _selectedRole,
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
            ),
            ListTile(
              title: const Text('ASHA Workers'),
              leading: Radio<String>(
                value: 'asha',
                groupValue: _selectedRole,
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
            ),
            ListTile(
              title: const Text('Doctors'),
              leading: Radio<String>(
                value: 'doctor',
                groupValue: _selectedRole,
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Date Range'),
              subtitle: Text(
                _startDate != null || _endDate != null
                    ? '${_startDate?.toString().split(' ').first ?? 'Start'} - ${_endDate?.toString().split(' ').first ?? 'End'}'
                    : 'Not selected',
              ),
              trailing: TextButton(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                  );
                  if (range != null) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end;
                    });
                  }
                },
                child: const Text('Select'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogTab extends StatelessWidget {
  final String? userRole;

  const _ActivityLogTab({this.userRole});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityLog>>(
      stream: FirebaseService.watchActivityLogs(
        userRole: userRole,
        limit: 200,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return const _EmptyState(
            icon: Icons.history_rounded,
            title: 'No Activity Logs',
            subtitle: 'Activity will appear here',
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

class _ActivityLogCard extends StatelessWidget {
  final ActivityLog log;

  const _ActivityLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: log.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(log.icon, color: log.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${log.userName} (${log.userRole.toUpperCase()}) • ${log.formattedTime}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Metadata
            if (log.metadata.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: log.metadata.entries.map((e) => Chip(
                  label: Text('${e.key}: ${e.value}'),
                  backgroundColor: Colors.grey[100],
                  labelStyle: const TextStyle(fontSize: 11),
                )).toList(),
              ),
            ],

            // Patient/Visit reference
            if (log.patientId != null || log.visitId != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (log.patientId != null) ...[
                    _RefChip(label: 'Patient', value: log.patientId!.substring(0, 8)),
                    const SizedBox(width: 8),
                  ],
                  if (log.visitId != null) ...[
                    _RefChip(label: 'Visit', value: log.visitId!.substring(0, 8)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RefChip extends StatelessWidget {
  final String label;
  final String value;

  const _RefChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 11)),
    );
  }
}

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}