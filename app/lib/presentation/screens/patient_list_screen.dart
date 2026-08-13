import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/patient_model.dart';
import '../../core/models/gramnidan_register.dart';
import '../../core/services/firebase_service.dart';
import '../widgets/asha_profile_dialog.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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

  void _showAshaProfileDialog() {
    AshaProfileDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54), // WhatsApp Dark Teal
        foregroundColor: Colors.white,
        elevation: 1,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _showAshaProfileDialog,
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ASHA Saathi',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'ASHA Health Hub • Active',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: const ListTile(
                  leading: Icon(Icons.account_circle_outlined, color: Color(0xFF075E54)),
                  title: Text('ASHA Profile & ID'),
                  dense: true,
                ),
                onTap: () => AshaProfileDialog.show(context),
              ),
              PopupMenuItem(
                value: 'signout',
                child: const ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                  dense: true,
                ),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/auth/login');
                },
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 18.0),
          indicatorColor: const Color(0xFF25D366), // WhatsApp Light Green Accent Line
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'PATIENTS'),
            Tab(text: 'REGISTERS'),
            Tab(text: 'VISITS'),
            Tab(text: 'UPDATES'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)))
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
                _RegistersTab(ashaId: _ashaId!),
                _VisitsTab(ashaId: _ashaId!),
                _UpdatesTab(ashaId: _ashaId!),
              ],
            ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          return _tabController.index == 0
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF00A884), // WhatsApp Emerald Green
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onPressed: _ashaId == null
                      ? _showSignInRequired
                      : () => context.push('/patient/new'),
                  tooltip: 'Add New Patient',
                  icon: const Icon(Icons.chat_rounded, size: 22),
                  label: const Text(
                    'New Patient',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Patient List Tab (WhatsApp Style) ──────────────────────────────────────────
class _PatientListTab extends StatefulWidget {
  final String ashaId;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  const _PatientListTab({
    required this.ashaId,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  State<_PatientListTab> createState() => _PatientListTabState();
}

class _PatientListTabState extends State<_PatientListTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<Patient>>(
      stream: FirebaseService.watchPatients(widget.ashaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00A884)));
        }

        if (snapshot.hasError) {
          final errorText = snapshot.error?.toString() ?? 'Unknown Supabase error';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'Patient error:\n$errorText',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final patients = snapshot.data ?? [];
        final filteredPatients = patients.where((p) {
          final matchesCategory = widget.selectedFilter == 'all' ||
              (p.registerType ?? 'patient') == widget.selectedFilter;
          if (!matchesCategory) return false;

          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              p.village.toLowerCase().contains(q) ||
              p.age.toString().contains(q);
        }).toList();

        if (patients.isEmpty) {
          return _EmptyPatientsState();
        }

        return Column(
          children: [
            // ── WhatsApp Search Bar ──────────────────────────────────────────
            Container(
              color: isDark ? const Color(0xFF111B21) : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF111B21),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search patient by name, village, age...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : const Color(0xFF667781),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : const Color(0xFF667781),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: isDark ? Colors.white54 : const Color(0xFF667781),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // ── Filter Chips ────────────────────────────────────────────────
            Container(
              color: isDark ? const Color(0xFF111B21) : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'All Patients',
                      selected: widget.selectedFilter == 'all',
                      onTap: () => widget.onFilterChanged('all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🤰 Pregnancy',
                      selected: widget.selectedFilter == 'pregnancy',
                      onTap: () => widget.onFilterChanged('pregnancy'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '👶 Newborn',
                      selected: widget.selectedFilter == 'newborn',
                      onTap: () => widget.onFilterChanged('newborn'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🧒 Child',
                      selected: widget.selectedFilter == 'child',
                      onTap: () => widget.onFilterChanged('child'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '🏘️ Household',
                      selected: widget.selectedFilter == 'household',
                      onTap: () => widget.onFilterChanged('household'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '❤️ BP / Sugar',
                      selected: widget.selectedFilter == 'ncd',
                      onTap: () => widget.onFilterChanged('ncd'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '📊 Monthly',
                      selected: widget.selectedFilter == 'monthly',
                      onTap: () => widget.onFilterChanged('monthly'),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF222D34) : const Color(0xFFE9EDEF)),

            // ── Patient List View ───────────────────────────────────────────
            Expanded(
              child: filteredPatients.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF202C33)
                                    : const Color(0xFFF0F2F5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 32,
                                color: Color(0xFF00A884),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No patients found for "$_searchQuery"'
                                  : 'No patients in this category',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : const Color(0xFF111B21),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Check spelling or try a different filter chip'
                                  : 'Tap the + New Patient button to add your first record',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF667781),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredPatients.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 82,
                        endIndent: 0,
                        color: isDark ? const Color(0xFF222D34) : const Color(0xFFE9EDEF),
                      ),
                      itemBuilder: (context, index) {
                        return _PatientTile(
                          patient: filteredPatients[index],
                          ashaId: widget.ashaId,
                        );
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
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          patient.name,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${patient.age}y • ${patient.village}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
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
            .where((p) => p.riskCategory == 'Red' || p.riskCategory == 'Orange')
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
                        color: theme.colorScheme.primary,
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
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.group_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$total',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Total Patients',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (red > 0 || orange > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${red + orange} URGENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Risk Distribution
              Text(
                'Risk Distribution',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RiskStatCard(
                    count: red,
                    label: 'Critical',
                    color: Colors.red,
                    icon: Icons.emergency_rounded,
                  ),
                  const SizedBox(width: 8),
                  _RiskStatCard(
                    count: orange,
                    label: 'Urgent',
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(width: 8),
                  _RiskStatCard(
                    count: yellow,
                    label: 'Monitor',
                    color: Colors.amber[700]!,
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(width: 8),
                  _RiskStatCard(
                    count: green,
                    label: 'Stable',
                    color: Colors.green,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Urgent Cases
              if (urgent.isNotEmpty) ...[
                Text(
                  '🚨 Patients Needing Attention',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ...urgent.map(
                  (p) => _UrgentPatientCard(patient: p, ashaId: ashaId),
                ),
                const SizedBox(height: 16),
              ],

              // All Patients Summary
              Text(
                'All Patients',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (patients.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No patients yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = selected
        ? (isDark ? const Color(0xFF103629) : const Color(0xFFD9FDD3))
        : (isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5));

    final textColor = selected
        ? (isDark ? const Color(0xFF25D366) : const Color(0xFF075E54))
        : (isDark ? Colors.white70 : const Color(0xFF54656F));

    final borderColor = selected
        ? const Color(0xFF00A884)
        : (isDark ? const Color(0xFF2A3942) : const Color(0xFFE9EDEF));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

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
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
        title: Text(
          patient.name,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${patient.age}y • ${patient.village}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            patient.riskCategory,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
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

class _DashboardPatientRow extends StatelessWidget {
  final Patient patient;
  const _DashboardPatientRow({required this.patient});

  @override
  Widget build(BuildContext context) {
    final riskColor =
        {
          'Red': Colors.red,
          'Orange': Colors.orange,
          'Yellow': Colors.amber[700]!,
          'Green': Colors.green,
        }[patient.riskCategory] ??
        Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
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
            child: Text(
              patient.name,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
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

// ── Patient Tile (WhatsApp Chat Style) ──────────────────────────────────────────
class _PatientTile extends StatelessWidget {
  final Patient patient;
  final String ashaId;
  const _PatientTile({required this.patient, required this.ashaId});

  Color get _riskColor {
    switch (patient.riskCategory) {
      case 'Red':
        return const Color(0xFFEF4444);
      case 'Orange':
        return const Color(0xFFF97316);
      case 'Yellow':
        return const Color(0xFFEAB308);
      default:
        return const Color(0xFF22C55E);
    }
  }

  Color _avatarBgColor(String name) {
    final colors = [
      const Color(0xFF075E54),
      const Color(0xFF128C7E),
      const Color(0xFF00A884),
      const Color(0xFF25D366),
      const Color(0xFF34B7F1),
      const Color(0xFF6A4C93),
      const Color(0xFFE76F51),
    ];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final visitId = await FirebaseService.createVisit(patient.id, ashaId);
        if (context.mounted) {
          context.push('/chat/${patient.id}/$visitId');
        }
      },
      child: Container(
        color: isDark ? const Color(0xFF111B21) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── Avatar + Risk Badge Overlay ──────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _avatarBgColor(patient.name),
                  child: Text(
                    patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: _riskColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF111B21) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // ── WhatsApp Message Content Column ──────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name + Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          patient.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF111B21),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(patient.lastMessageTime ?? DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: patient.riskCategory == 'Red'
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white54 : const Color(0xFF667781)),
                          fontWeight: patient.riskCategory == 'Red'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: WhatsApp Double Checkmarks + Last Message
                  Row(
                    children: [
                      const Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: Color(0xFF53BDEB), // WhatsApp blue ticks
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          patient.lastMessage ?? 'Tap to start AI chat visit',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white70 : const Color(0xFF667781),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Row 3: Details + Register Type Chip + Risk Badge
                  Row(
                    children: [
                      Text(
                        '${patient.age}y • ${patient.village}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : const Color(0xFF8696A0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if ((patient.registerType ?? '').isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF103629)
                                : const Color(0xFFD9FDD3), // WhatsApp light green
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00A884).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _registerLabel(patient.registerType!),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? const Color(0xFF25D366)
                                  : const Color(0xFF075E54),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _riskColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          patient.riskCategory.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            color: _riskColor,
                            fontWeight: FontWeight.w800,
                          ),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final m = time.minute.toString().padLeft(2, '0');
      final p = time.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}';
    }
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the + button to add your first patient and start a health visit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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

class _RegistersTab extends StatelessWidget {
  final String ashaId;
  const _RegistersTab({required this.ashaId});

  static const _quickShortcuts = [
    {'id': 'pregnancy', 'emoji': '🤰', 'label': 'Pregnancy'},
    {'id': 'newborn', 'emoji': '👶', 'label': 'Newborn'},
    {'id': 'child', 'emoji': '🧒', 'label': 'Child Health'},
    {'id': 'household', 'emoji': '🏘️', 'label': 'Household'},
    {'id': 'bpsugar', 'emoji': '❤️', 'label': 'BP / Sugar'},
    {'id': 'cbac', 'emoji': '🩺', 'label': 'CBAC'},
    {'id': 'idsp', 'emoji': '🦟', 'label': 'IDSP'},
    {'id': 'monthly', 'emoji': '📊', 'label': 'Monthly'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<GramNidanRegister>>(
      stream: FirebaseService.watchGramNidanRegisters(ashaId),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ── Hero Voice Register Card ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B4332), // Emerald 900
                    Color(0xFF2D6A4F), // Emerald 700
                    Color(0xFF081C15), // Deep Dark Green
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B4332).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.mic_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'AI VOICE ASSISTANT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'GramNidan Voice Registers',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '11 Official Registers • Voice Extraction',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No manual paper typing needed. Select a register and record patient notes in Hindi, Marathi, or English. AI will extract all register fields automatically.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.mic_rounded, size: 20),
                        label: const Text(
                          'Start Voice Entry',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1B4332),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () =>
                            context.push('/dashboard/asha/registers'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick Access Category Grid ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Voice Shortcuts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B4332),
                  ),
                ),
                Text(
                  '8 Registers',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickShortcuts.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => context.push(
                        '/dashboard/asha/registers',
                        extra: item['id'],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF2D6A4F).withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              item['emoji']!,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item['label']!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1B4332),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 28),

            // ── Past Voice Log Entries Section ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Past Voice Submissions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B4332),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D6A4F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${records.length} Recorded',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D6A4F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (records.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_none_rounded,
                        size: 38,
                        color: Color(0xFF2D6A4F),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Voice Submissions Yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap "Start Voice Entry" above to record your first GramNidan register entry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else
              ...records.map((reg) {
                final isSubmitted = reg.submittedToTho || reg.pdfUrl != null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          reg.icon,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    title: Text(
                      reg.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient: ${reg.patientName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Recorded: ${reg.createdAt.day}/${reg.createdAt.month}/${reg.createdAt.year}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSubmitted
                                ? const Color(0xFF2D6A4F).withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSubmitted
                                  ? const Color(0xFF2D6A4F).withValues(alpha: 0.4)
                                  : Colors.blue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isSubmitted ? 'Sent to MO' : 'Local Draft',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSubmitted
                                  ? const Color(0xFF2D6A4F)
                                  : Colors.blue[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      context.push('/gramnidan/register/${reg.id}');
                    },
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

