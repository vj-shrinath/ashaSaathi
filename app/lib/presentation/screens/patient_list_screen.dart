import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/patient_model.dart';
import '../../core/models/activity_log.dart';
import '../../core/services/firebase_service.dart';
import '../../core/models/user_role.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _ashaId;
  bool _isLoading = true;
  String _patientFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initAshaId();
  }

  Future<void> _initAshaId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (mounted) {
      setState(() {
        _ashaId = user?.id;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSignInRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please sign in to view patients')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ASHA Saathi',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              'My Patients',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () {},
          ),
          PopupMenuButton<UserRole>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (role) {
              if (role == UserRole.doctor) {
                context.go('/dashboard/doctor');
              } else if (role == UserRole.admin) {
                context.go('/admin');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: UserRole.asha,
                child: ListTile(
                  leading: Icon(Icons.medical_services, color: Color(0xFF2E7D32)),
                  title: Text('ASHA Worker'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: UserRole.doctor,
                child: ListTile(
                  leading: Icon(Icons.local_hospital, color: Color(0xFF0277BD)),
                  title: Text('Doctor View'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: UserRole.admin,
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings, color: Color(0xFF6A1B9A)),
                  title: Text('Admin View'),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: UserRole.asha,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                  dense: true,
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/auth/login');
                  },
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'PATIENTS'),
            Tab(text: 'VISITS'),
            Tab(text: 'UPDATES'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ashaId == null
              ? const _SignedOutState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _PatientListTab(
                      ashaId: _ashaId!,
                      selectedFilter: _patientFilter,
                      onFilterChanged: (value) =>
                          setState(() => _patientFilter = value),
                    ),
                    _VisitsTab(ashaId: _ashaId!),
                    _UpdatesTab(ashaId: _ashaId!),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        onPressed: _ashaId == null
            ? _showSignInRequired
            : () => context.push('/patient/new'),
        tooltip: 'Add New Patient',
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }

  void _showAddPatientDialog() {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final villageCtrl = TextEditingController();
    String selectedGender = 'F';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF075E54),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add New Patient',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('नया मरीज़ जोड़ें',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Patient Name *',
                    hintText: 'e.g. Sunita Devi',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Age *',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: const Icon(Icons.wc_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'F', child: Text('Female')),
                          DropdownMenuItem(value: 'M', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => selectedGender = v ?? 'F'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: villageCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Village / Area *',
                    hintText: 'e.g. Rampur',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          ageCtrl.text.trim().isEmpty ||
                          villageCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill all required fields')),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);

                      try {
                        final ashaId = _ashaId;
                        if (ashaId == null) {
                          throw StateError('No signed-in Supabase user');
                        }

                        // 1. Create patient in Supabase
                        final patient = Patient(
                          id: '',
                          name: nameCtrl.text.trim(),
                          age: int.tryParse(ageCtrl.text) ?? 0,
                          village: villageCtrl.text.trim(),
                          ashaId: ashaId,
                          lastMessage: 'Patient added',
                          lastMessageTime: DateTime.now(),
                        );
                        final patientId =
                            await FirebaseService.createPatient(patient);

                        // 2. Immediately create a visit session
                        final visitId = await FirebaseService.createVisit(
                          patientId,
                          ashaId,
                        );

                        // 3. Log activity
                        await FirebaseService.logActivity(
                          ActivityType.patientCreated,
                          'Added new patient: ${patient.name}',
                          metadata: {
                            'patientId': patientId,
                            'visitId': visitId,
                          },
                          patientId: patientId,
                          visitId: visitId,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        // 4. Auto-navigate to the new patient's chat
                        if (mounted) {
                          context.push('/chat/$patientId/$visitId');
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Error adding patient: ${e.toString()}')),
                          );
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add_rounded, size: 18),
              label: Text(isSubmitting ? 'Adding...' : 'Add & Open Visit'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient List Tab ───────────────────────────────────────────────────────────
class _PatientListTab extends StatelessWidget {
  final String ashaId;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  const _PatientListTab({
    required this.ashaId,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Patient>>(
      stream: FirebaseService.watchPatients(ashaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final errorText = snapshot.error?.toString() ?? 'Unknown Supabase error';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Patient error:\n$errorText',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        final patients = snapshot.data ?? [];
        final filteredPatients = selectedFilter == 'all'
            ? patients
            : patients
                .where((p) => (p.registerType ?? 'patient') == selectedFilter)
                .toList();

        if (patients.isEmpty) {
          return _EmptyPatientsState();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Patients',
                      selected: selectedFilter == 'all',
                      onTap: () => onFilterChanged('all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pregnancy',
                      selected: selectedFilter == 'pregnancy',
                      onTap: () => onFilterChanged('pregnancy'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Newborn',
                      selected: selectedFilter == 'newborn',
                      onTap: () => onFilterChanged('newborn'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Child',
                      selected: selectedFilter == 'child',
                      onTap: () => onFilterChanged('child'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Household',
                      selected: selectedFilter == 'household',
                      onTap: () => onFilterChanged('household'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'NCD',
                      selected: selectedFilter == 'ncd',
                      onTap: () => onFilterChanged('ncd'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Monthly',
                      selected: selectedFilter == 'monthly',
                      onTap: () => onFilterChanged('monthly'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filteredPatients.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 0,
                  indent: 72,
                  endIndent: 0,
                ),
                itemBuilder: (context, index) {
                  return _PatientTile(patient: filteredPatients[index], ashaId: ashaId);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Visits Tab ────────────────────────────────────────────────────────────────
class _VisitsTab extends StatelessWidget {
  final String ashaId;
  const _VisitsTab({required this.ashaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Patient>>(
      stream: FirebaseService.watchPatients(ashaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final patients = snapshot.data ?? [];

        if (patients.isEmpty) {
          return _EmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No Visits Yet',
            subtitle: 'Start a visit from the Patients tab',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final patient = patients[index];
            return _VisitCard(patient: patient, ashaId: ashaId);
          },
        );
      },
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Patient patient;
  final String ashaId;
  const _VisitCard({required this.patient, required this.ashaId});

  Color get _riskColor {
    switch (patient.riskCategory) {
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
    return Card(
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _riskColor.withValues(alpha: 0.15),
              child: Text(
                patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: _riskColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _riskColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(patient.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${patient.age}y • ${patient.village}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _riskColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _riskColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            patient.riskCategory,
            style: TextStyle(
              fontSize: 10,
              color: _riskColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () async {
          final visitId = await FirebaseService.createVisit(patient.id, ashaId);
          if (context.mounted) {
            context.push('/chat/${patient.id}/$visitId');
          }
        },
      ),
    );
  }
}

// ── Updates Tab (ASHA Daily Dashboard) ────────────────────────────────────────
class _UpdatesTab extends StatelessWidget {
  final String ashaId;
  const _UpdatesTab({required this.ashaId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Patient>>(
      stream: FirebaseService.watchPatients(ashaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final patients = snapshot.data ?? [];
        final total = patients.length;
        final red = patients.where((p) => p.riskCategory == 'Red').length;
        final orange = patients.where((p) => p.riskCategory == 'Orange').length;
        final yellow = patients.where((p) => p.riskCategory == 'Yellow').length;
        final green = patients.where((p) => p.riskCategory == 'Green').length;
        final urgent = patients
            .where((p) =>
                p.riskCategory == 'Red' || p.riskCategory == 'Orange')
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'आज का डैशबोर्ड',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF075E54),
                      ),
                    ),
                  ),
                  Text(
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Patients Count
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF075E54), Color(0xFF25D366)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF075E54).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group_rounded, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Patients',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const Spacer(),
                    if (red > 0 || orange > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${red + orange} URGENT',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Risk Distribution
              Text('Risk Distribution',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RiskStatCard(
                      count: red,
                      label: 'Critical',
                      color: Colors.red,
                      icon: Icons.emergency_rounded),
                  const SizedBox(width: 8),
                  _RiskStatCard(
                      count: orange,
                      label: 'Urgent',
                      color: Colors.orange,
                      icon: Icons.warning_amber_rounded),
                  const SizedBox(width: 8),
                  _RiskStatCard(
                      count: yellow,
                      label: 'Monitor',
                      color: Colors.amber[700]!,
                      icon: Icons.info_outline_rounded),
                  const SizedBox(width: 8),
                  _RiskStatCard(
                      count: green,
                      label: 'Stable',
                      color: Colors.green,
                      icon: Icons.check_circle_outline_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // Urgent Cases
              if (urgent.isNotEmpty) ...[
                Text('🚨 Patients Needing Attention',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...urgent.map((p) => _UrgentPatientCard(patient: p, ashaId: ashaId)),
                const SizedBox(height: 16),
              ],

              // All Patients Summary
              Text('All Patients',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (patients.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('No patients yet',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else
                ...patients.map((p) => _DashboardPatientRow(patient: p)),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF075E54).withValues(alpha: 0.14),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF075E54) : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF075E54) : Colors.grey.shade300,
      ),
    );
  }
}

class _RiskStatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _RiskStatCard(
      {required this.count,
      required this.label,
      required this.color,
      required this.icon});

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
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentPatientCard extends StatelessWidget {
  final Patient patient;
  final String ashaId;
  const _UrgentPatientCard({required this.patient, required this.ashaId});

  @override
  Widget build(BuildContext context) {
    final isRed = patient.riskCategory == 'Red';
    final color = isRed ? Colors.red : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(patient.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${patient.age}y • ${patient.village}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            patient.riskCategory,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () async {
          final visitId = await FirebaseService.createVisit(patient.id, ashaId);
          if (context.mounted) {
            context.push('/chat/${patient.id}/$visitId');
          }
        },
      ),
    );
  }
}

class _DashboardPatientRow extends StatelessWidget {
  final Patient patient;
  const _DashboardPatientRow({required this.patient});

  @override
  Widget build(BuildContext context) {
    final riskColor = {
      'Red': Colors.red,
      'Orange': Colors.orange,
      'Yellow': Colors.amber[700]!,
      'Green': Colors.green,
    }[patient.riskCategory] ?? Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(patient.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(
            '${patient.age}y • ${patient.village}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Patient Tile (for PATIENTS tab) ────────────────────────────────────────────
class _PatientTile extends StatelessWidget {
  final Patient patient;
  final String ashaId;
  const _PatientTile({required this.patient, required this.ashaId});

  Color get _riskColor {
    switch (patient.riskCategory) {
      case 'Red':
        return Colors.red;
      case 'Orange':
        return Colors.orange;
      case 'Yellow':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        final visitId = await FirebaseService.createVisit(patient.id, ashaId);
        if (context.mounted) {
          context.push('/chat/${patient.id}/$visitId');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _riskColor.withValues(alpha: 0.15),
                  child: Text(
                    patient.name.isNotEmpty
                        ? patient.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                // Risk dot
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _riskColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.scaffoldBackgroundColor, width: 2),
                    ),
                  ),
                ),
              ],
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
                          patient.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (patient.lastMessageTime != null)
                        Text(
                          _formatTime(patient.lastMessageTime!),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${patient.age}y • ${patient.village}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      const Spacer(),
                      if ((patient.registerType ?? '').isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF075E54).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _registerLabel(patient.registerType!),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF075E54),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _riskColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          patient.riskCategory,
                          style: TextStyle(
                            fontSize: 10,
                            color: _riskColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (patient.lastMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        patient.lastMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      final h = time.hour > 12 ? time.hour - 12 : time.hour == 0 ? 12 : time.hour;
      final m = time.minute.toString().padLeft(2, '0');
      final p = time.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    }
    return '${time.day}/${time.month}';
  }
}

// ── Empty States ──────────────────────────────────────────────────────────────
class _EmptyPatientsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Patients Yet',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the + button to add your first patient and start a health visit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              'Sign in to load patients',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The live patient list uses the current Supabase session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterOption {
  final String key;
  final String label;
  final IconData icon;
  final String subtitle;

  const _RegisterOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.subtitle,
  });
}

String _registerLabel(String key) {
  switch (key) {
    case 'pregnancy':
      return 'Pregnancy';
    case 'newborn':
      return 'Newborn';
    case 'child':
      return 'Child Health';
    case 'household':
      return 'Household Survey';
    case 'ncd':
      return 'BP / Sugar';
    case 'monthly':
      return 'Monthly Report';
    default:
      return 'General';
  }
}

class _RegisterTypeSelector extends StatelessWidget {
  final List<_RegisterOption> options;
  final String selectedKey;
  final ValueChanged<String> onChanged;

  const _RegisterTypeSelector({
    required this.options,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.key == selectedKey;
          final theme = Theme.of(context);
            return InkWell(
              onTap: () => onChanged(option.key),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 152,
                padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF075E54).withValues(alpha: 0.12)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF075E54)
                      : theme.colorScheme.outline.withValues(alpha: 0.18),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(option.icon,
                          color: isSelected
                              ? const Color(0xFF075E54)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Color(0xFF075E54), size: 18),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    option.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF075E54) : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
