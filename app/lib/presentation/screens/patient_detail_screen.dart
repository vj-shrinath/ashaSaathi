import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/patient_model.dart';
import '../../core/services/firebase_service.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  Patient? _patient;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  Future<void> _loadPatient() async {
    try {
      final patient = await FirebaseService.getPatient(widget.patientId);
      if (mounted) {
        setState(() {
          _patient = patient;
          _isLoading = false;
          if (patient == null) {
            _error = 'Patient not found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading patient: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Color get _riskColor {
    switch (_patient?.riskCategory) {
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(_error ?? 'Patient not found',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/dashboard/asha'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final patient = _patient!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_riskColor.withValues(alpha: 0.8), _riskColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: patient.photoUrl != null
                            ? NetworkImage(patient.photoUrl!)
                            : null,
                        child: patient.photoUrl == null
                            ? Text(
                                patient.name.isNotEmpty
                                    ? patient.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        patient.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${patient.riskCategory} Risk',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoCard(
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: '${patient.age} years',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.location_on_outlined,
                    label: 'Village / Area',
                    value: patient.village,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.medical_services_outlined,
                    label: 'Risk Category',
                    value: patient.riskCategory,
                    color: _riskColor,
                    valueStyle: TextStyle(
                        color: _riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (patient.lastMessage != null) ...[
                    _InfoCard(
                      icon: Icons.chat_bubble_outline,
                      label: 'Last Message',
                      value: patient.lastMessage!,
                      color: theme.colorScheme.secondary,
                      multiline: true,
                    ),
                    if (patient.lastMessageTime != null) ...[
                      const SizedBox(height: 12),
                      _InfoCard(
                        icon: Icons.access_time,
                        label: 'Last Updated',
                        value: _formatDateTime(patient.lastMessageTime!),
                        color: theme.colorScheme.outline,
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final ashaId = Supabase.instance.client.auth.currentUser?.id ?? '';
                            if (ashaId.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please sign in first')),
                                );
                              }
                              return;
                            }
                            final visitId =
                                await FirebaseService.createVisit(patient.id, ashaId);
                            if (context.mounted) {
                              context.push('/chat/${patient.id}/$visitId');
                            }
                          },
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('Start Visit'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF075E54),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/emergency/${patient.id}'),
                          icon: const Icon(Icons.emergency_rounded, color: Colors.red),
                          label: const Text('Emergency',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      final h = time.hour > 12 ? time.hour - 12 : time.hour == 0 ? 12 : time.hour;
      final m = time.minute.toString().padLeft(2, '0');
      final p = time.hour >= 12 ? 'PM' : 'AM';
      return 'Today at $h:$m $p';
    }
    return '${time.day}/${time.month}/${time.year}';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final TextStyle? valueStyle;
  final bool multiline;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.valueStyle,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: valueStyle ??
                        theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600),
                    maxLines: multiline ? null : 2,
                    overflow: multiline ? null : TextOverflow.ellipsis,
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

extension FirebaseServiceExtension on FirebaseService {
  static String getAshaId() {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id ?? '';
  }
}
