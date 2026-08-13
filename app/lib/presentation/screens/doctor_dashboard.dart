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
  _DashboardFilter _selectedFilter = _DashboardFilter.allPatients;
  bool _loadingScope = true;
  Set<String> _scopedAshaIds = {};
  String? _doctorId;
  String? _doctorName;
  String? _phcName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final Stream<List<TriageReport>> _triageStream;

  @override
  void initState() {
    super.initState();
    _triageStream = FirebaseService.watchTriageReports();
    _loadDoctorScope();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorScope() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint("[DoctorScope] ERROR: No authenticated user!");
        if (mounted) setState(() => _loadingScope = false);
        return;
      }
      _doctorId = user.id;

      // 1. Fetch current doctor profile to find phc_id and name
      final docProfile = await Supabase.instance.client
          .from('user_profiles')
          .select('phc_id, full_name')
          .eq('id', user.id)
          .maybeSingle();

      final phcId = docProfile != null ? docProfile['phc_id'] as String? : null;
      _doctorName = docProfile != null ? docProfile['full_name'] as String? : null;

      String? phcName;
      if (phcId != null) {
        final phcProfile = await Supabase.instance.client
            .from('phcs')
            .select('name')
            .eq('id', phcId)
            .maybeSingle();
        phcName = phcProfile != null ? phcProfile['name'] as String? : null;
        _phcName = phcName;
      }

      final Set<String> ashaSet = {};

      if (phcId != null) {
        // Fetch ASHA IDs in the doctor's PHC
        final ashaRows = await Supabase.instance.client
            .from('user_profiles')
            .select('id')
            .eq('role', 'asha')
            .eq('phc_id', phcId);
        ashaSet.addAll((ashaRows as List).map((r) => r['id'] as String));
      }

      // Also explicitly fetch ASHAs assigned directly to this doctor
      final directAshaRows = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('role', 'asha')
          .eq('doctor_id', user.id);
      
      ashaSet.addAll((directAshaRows as List).map((r) => r['id'] as String));

      if (mounted) {
        setState(() {
          _scopedAshaIds = ashaSet;
          _loadingScope = false;
        });
      }
    } catch (e, stack) {
      debugPrint("[DoctorScope] EXCEPTION: $e");
      debugPrint("[DoctorScope] Stack: $stack");
      if (mounted) {
        setState(() => _loadingScope = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingScope) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F4C81).withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  color: Color(0xFF0F4C81),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading Doctor Workspace...',
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/dashboard/doctor/patients');
        },
        icon: const Icon(Icons.add_task_rounded, size: 22),
        label: const Text(
          'Prescribe Medication',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.2),
        ),
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0F4C81),
          onRefresh: () async {
            await _loadDoctorScope();
            setState(() {});
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 1. Hero Doctor Header
              SliverToBoxAdapter(
                child: _DoctorHeroHeader(
                  doctorName: _doctorName,
                  phcName: _phcName,
                  onRefresh: () {
                    _loadDoctorScope();
                    setState(() {});
                  },
                  onSignOut: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/auth/login');
                  },
                ),
              ),

              // Main Dashboard Body Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 2. Quick Search Bar
                    _SearchBar(
                      controller: _searchController,
                      searchQuery: _searchQuery,
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),

                    const SizedBox(height: 16),

                    // 3. Triage Risk Summary Grid
                    _SummaryGrid(
                      stream: _triageStream,
                      selectedFilter: _selectedFilter,
                      onSelected: (filter) => setState(() => _selectedFilter = filter),
                      myAshaIds: _scopedAshaIds,
                    ),

                    const SizedBox(height: 18),

                    // 4. Horizontal Section Pills / Filters
                    _SectionPills(
                      selectedFilter: _selectedFilter,
                      onSelected: (filter) => setState(() => _selectedFilter = filter),
                    ),

                    const SizedBox(height: 18),

                    // 5. Section Header Title with Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F4C81),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedFilter.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        if (_searchQuery.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Filter: "$_searchQuery"',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F4C81),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 6. Patient Feed Content List
                    _PatientFeedPanel(
                      stream: _triageStream,
                      filter: _selectedFilter,
                      myAshaIds: _scopedAshaIds,
                      doctorId: _doctorId,
                      searchQuery: _searchQuery,
                    ),

                    const SizedBox(height: 80), // Padding for FAB
                  ]),
                ),
              ),
            ],
          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _DoctorHeroHeader extends StatelessWidget {
  final String? doctorName;
  final String? phcName;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  const _DoctorHeroHeader({
    this.doctorName,
    this.phcName,
    required onRefresh,
    required onSignOut,
  })  : onRefresh = onRefresh,
        onSignOut = onSignOut;

  @override
  Widget build(BuildContext context) {
    final displayName = (doctorName != null && doctorName!.isNotEmpty)
        ? doctorName!
        : 'Doctor Workspace';

    final dateStr = _getFormattedDate();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E293B), // Slate 800
            Color(0xFF0F4C81), // Deep Medical Blue
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x200F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Profile Avatar, Greetings & Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with online status
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981), // Emerald active green
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Doctor Name with multi-line wrap support for long names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dr. ${doctorName ?? "Doctor"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Action Buttons (Refresh & Sign Out)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh Data',
                    onPressed: onRefresh,
                  ),
                  const SizedBox(width: 6),
                  _HeaderIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'Sign Out',
                    onPressed: onSignOut,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sub-row: PHC Badge + Triage Live Status
          Row(
            children: [
              if (phcName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_hospital_rounded,
                          size: 13, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          phcName!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: Color(0xFF34D399)),
                    SizedBox(width: 5),
                    Text(
                      'Triage Live',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Sub-header Banner Card inside Hero
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medical_services_rounded,
                      color: Color(0xFF38BDF8), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Patient Triage',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time ASHA reports • Quick review & prescriptions',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${now.day} ${months[now.month - 1]}';
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.searchQuery,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search patient by name, ASHA, or symptoms...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0F4C81), size: 22),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 18),
                  onPressed: onClear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 1.8),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY GRID
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryGrid extends StatelessWidget {
  final Stream<List<TriageReport>> stream;
  final _DashboardFilter selectedFilter;
  final ValueChanged<_DashboardFilter> onSelected;
  final Set<String> myAshaIds;

  const _SummaryGrid({
    required this.stream,
    required this.selectedFilter,
    required this.onSelected,
    required this.myAshaIds,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TriageReport>>(
      stream: stream,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
        final rawReports = snapshot.data ?? [];
        final reports = myAshaIds.isNotEmpty
            ? rawReports.where((r) => myAshaIds.contains(r.ashaId)).toList()
            : rawReports;
        final latestByPatient = <String, TriageReport>{};
        for (final r in reports) {
          latestByPatient.putIfAbsent(r.patientId, () => r);
        }
        final unique = latestByPatient.values.toList();
        final red = unique.where((r) => r.triageResult.riskCategory == 'Red').length;
        final orange = unique.where((r) => r.triageResult.riskCategory == 'Orange').length;
        final yellow = unique.where((r) => r.triageResult.riskCategory == 'Yellow').length;
        final green = unique.where((r) => r.triageResult.riskCategory == 'Green').length;

        final urgentVal = isLoading ? '...' : '${red + orange}';
        final monitorVal = isLoading ? '...' : '$yellow';
        final stableVal = isLoading ? '...' : '$green';
        final totalVal = isLoading ? '...' : '${unique.length}';

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _StatCard(
              label: 'Urgent Cases',
              value: urgentVal,
              subLabel: '$red Critical • $orange High',
              color: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
              icon: Icons.error_rounded,
              selected: selectedFilter == _DashboardFilter.urgent,
              onTap: () => onSelected(_DashboardFilter.urgent),
            ),
            _StatCard(
              label: 'Needs Monitor',
              value: monitorVal,
              subLabel: 'Moderate Risk',
              color: const Color(0xFFD97706),
              bgColor: const Color(0xFFFEF3C7),
              icon: Icons.monitor_heart_rounded,
              selected: selectedFilter == _DashboardFilter.monitor,
              onTap: () => onSelected(_DashboardFilter.monitor),
            ),
            _StatCard(
              label: 'Stable Patients',
              value: stableVal,
              subLabel: 'Low Risk Queue',
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              icon: Icons.check_circle_rounded,
              selected: selectedFilter == _DashboardFilter.stable,
              onTap: () => onSelected(_DashboardFilter.stable),
            ),
            _StatCard(
              label: 'Total Patients',
              value: totalVal,
              subLabel: 'All Triage Cases',
              color: const Color(0xFF0F4C81),
              bgColor: const Color(0xFFF0F9FF),
              icon: Icons.groups_rounded,
              selected: selectedFilter == _DashboardFilter.allPatients,
              onTap: () => onSelected(_DashboardFilter.allPatients),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? bgColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? color.withValues(alpha: 0.15)
                    : const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? color : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION PILLS / FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SectionPills extends StatelessWidget {
  final _DashboardFilter selectedFilter;
  final ValueChanged<_DashboardFilter> onSelected;

  const _SectionPills({
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _pill('All Triage', Icons.analytics_rounded, const Color(0xFF0F4C81), _DashboardFilter.allPatients),
          const SizedBox(width: 8),
          _pill('Urgent', Icons.emergency_rounded, const Color(0xFFEF4444), _DashboardFilter.urgent),
          const SizedBox(width: 8),
          _pill('Monitor', Icons.monitor_heart_rounded, const Color(0xFFD97706), _DashboardFilter.monitor),
          const SizedBox(width: 8),
          _pill('Stable', Icons.check_circle_rounded, const Color(0xFF10B981), _DashboardFilter.stable),
          const SizedBox(width: 8),
          _pill('Pending Review', Icons.pending_actions_rounded, const Color(0xFFF97316), _DashboardFilter.pending),
          const SizedBox(width: 8),
          _pill('Prescriptions', Icons.medication_rounded, const Color(0xFF8B5CF6), _DashboardFilter.prescriptions),
          const SizedBox(width: 8),
          _pill('Activity Log', Icons.history_rounded, const Color(0xFF059669), _DashboardFilter.activity),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon, Color color, _DashboardFilter filter) {
    final selected = selectedFilter == filter;
    return InkWell(
      onTap: () => onSelected(filter),
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF334155),
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PATIENT FEED PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _PatientFeedPanel extends StatelessWidget {
  final Stream<List<TriageReport>> stream;
  final _DashboardFilter filter;
  final Set<String> myAshaIds;
  final String? doctorId;
  final String searchQuery;

  const _PatientFeedPanel({
    required this.stream,
    required this.filter,
    required this.myAshaIds,
    required this.doctorId,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (filter == _DashboardFilter.pending) {
      return _PendingReviewTab(stream: stream, myAshaIds: myAshaIds, searchQuery: searchQuery);
    }
    if (filter == _DashboardFilter.prescriptions) {
      return _PrescriptionsTab(doctorId: doctorId, searchQuery: searchQuery);
    }
    if (filter == _DashboardFilter.activity) {
      return _ActivityFeedTab(myAshaIds: myAshaIds, searchQuery: searchQuery);
    }

    return StreamBuilder<List<TriageReport>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81))),
          );
        }

        final rawReports = snapshot.data ?? [];
        final reports = myAshaIds.isNotEmpty
            ? rawReports.where((r) => myAshaIds.contains(r.ashaId)).toList()
            : rawReports;
        final latestByPatient = <String, TriageReport>{};
        for (final report in reports) {
          latestByPatient.putIfAbsent(report.patientId, () => report);
        }

        var items = latestByPatient.values.toList();

        // 1. Filter by Dashboard Risk Filter
        switch (filter) {
          case _DashboardFilter.urgent:
            items = items
                .where((r) =>
                    r.triageResult.riskCategory == 'Red' ||
                    r.triageResult.riskCategory == 'Orange')
                .toList();
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

        // 2. Filter by Search Query
        if (searchQuery.isNotEmpty) {
          items = items.where((r) {
            final patientMatch = r.patientName.toLowerCase().contains(searchQuery);
            final ashaMatch = r.ashaName.toLowerCase().contains(searchQuery);
            final summaryMatch = r.triageResult.patientSummary.toLowerCase().contains(searchQuery);
            final symptomsMatch = r.triageResult.symptoms
                .any((s) => s.toLowerCase().contains(searchQuery));
            return patientMatch || ashaMatch || summaryMatch || symptomsMatch;
          }).toList();
        }

        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (items.isEmpty) {
          return _EmptyState(
            icon: Icons.search_off_rounded,
            title: searchQuery.isNotEmpty ? 'No Matching Patients' : 'No Patients Found',
            subtitle: searchQuery.isNotEmpty
                ? 'No patient matches "$searchQuery". Try clearing search.'
                : 'No patients in this category yet.',
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) => _PatientTriageTile(report: items[index]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PATIENT TRIAGE TILE
// ─────────────────────────────────────────────────────────────────────────────
class _PatientTriageTile extends StatelessWidget {
  final TriageReport report;

  const _PatientTriageTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final (riskColor, riskBgColor, riskBorderColor, riskLabel) = switch (
        report.triageResult.riskCategory) {
      'Red' => (
          const Color(0xFFEF4444),
          const Color(0xFFFEF2F2),
          const Color(0xFFFCA5A5),
          'CRITICAL RED'
        ),
      'Orange' => (
          const Color(0xFFF97316),
          const Color(0xFFFFF7ED),
          const Color(0xFFFDBA74),
          'HIGH ORANGE'
        ),
      'Yellow' => (
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          const Color(0xFFFDE68A),
          'MONITOR YELLOW'
        ),
      _ => (
          const Color(0xFF10B981),
          const Color(0xFFECFDF5),
          const Color(0xFFA7F3D0),
          'STABLE GREEN'
        ),
    };

    final isPending = !report.reviewedByDoctor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending ? riskColor.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Risk Accent Bar
              Container(
                width: 6,
                color: riskColor,
              ),

              // Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Patient Avatar
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: riskColor.withValues(alpha: 0.12),
                            child: Text(
                              report.patientName.isNotEmpty
                                  ? report.patientName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: riskColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Patient Name & Subtitle
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
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    // Risk Category Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: riskBgColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: riskBorderColor),
                                      ),
                                      child: Text(
                                        riskLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: riskColor,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded,
                                        size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'ASHA: ${report.ashaName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                                    const SizedBox(width: 8),
                                    Icon(Icons.schedule_rounded,
                                        size: 12, color: Colors.grey[500]),
                                    const SizedBox(width: 3),
                                    Text(
                                      _formatDate(report.createdAt),
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Patient Summary Text Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Text(
                          report.triageResult.patientSummary.isNotEmpty
                              ? report.triageResult.patientSummary
                              : 'Voice triage recorded by ASHA worker.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Symptoms Chips (if available)
                      if (report.triageResult.symptoms.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: report.triageResult.symptoms.take(3).map((sym) {
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '• $sym',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Doctor Action Toolbar (Highly accessible big buttons)
                      Row(
                        children: [
                          // 1. Open Doctor Sheet Button (Primary clinical action)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context
                                  .push('/doctor-sheet/${report.patientId}'),
                              icon: const Icon(Icons.assignment_rounded, size: 16),
                              label: const Text(
                                'Doctor Sheet',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F4C81),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. Prescribe Button
                          OutlinedButton.icon(
                            onPressed: () => context.push(
                                '/prescription/${report.patientId}/${report.visitId}'),
                            icon: const Icon(Icons.medication_rounded,
                                size: 16, color: Color(0xFF8B5CF6)),
                            label: const Text(
                              'Prescribe',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFDDD6FE)),
                              backgroundColor: const Color(0xFFF5F3FF),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // 3. Chat with ASHA Button
                          IconButton(
                            onPressed: () {
                              final visitId = report.visitId.isNotEmpty
                                  ? report.visitId
                                  : null;
                              if (visitId == null) {
                                context.push(
                                    '/dashboard/doctor/patient/${report.patientId}');
                                return;
                              }
                              context.push('/chat/${report.patientId}/$visitId');
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                            color: const Color(0xFF0284C7),
                            tooltip: 'Chat with ASHA',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF0F9FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          // 4. Mark Reviewed Checkbox
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () async {
                              await FirebaseService.markReportReviewed(report.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(report.reviewedByDoctor
                                        ? 'Report marked unreviewed'
                                        : 'Report marked as reviewed'),
                                    backgroundColor: const Color(0xFF0F4C81),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              report.reviewedByDoctor
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 22,
                              color: report.reviewedByDoctor
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                            ),
                            tooltip: report.reviewedByDoctor
                                ? 'Reviewed'
                                : 'Mark Reviewed',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING REVIEW TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PendingReviewTab extends StatelessWidget {
  final Stream<List<TriageReport>> stream;
  final Set<String> myAshaIds;
  final String searchQuery;

  const _PendingReviewTab({
    required this.stream,
    required this.myAshaIds,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TriageReport>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81))),
          );
        }

        final rawReports = snapshot.data ?? [];
        final reports = myAshaIds.isNotEmpty
            ? rawReports.where((r) => myAshaIds.contains(r.ashaId)).toList()
            : rawReports;
        var pending = reports.where((r) => !r.reviewedByDoctor).toList();

        if (searchQuery.isNotEmpty) {
          pending = pending.where((r) {
            return r.patientName.toLowerCase().contains(searchQuery) ||
                r.ashaName.toLowerCase().contains(searchQuery);
          }).toList();
        }

        if (pending.isEmpty) {
          return const _EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'All Caught Up!',
            subtitle: 'No pending triage reports requiring your review',
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final report = pending[index];
            return _PatientTriageTile(report: report);
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
  final String? doctorId;
  final String searchQuery;

  const _PrescriptionsTab({
    required this.doctorId,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prescription>>(
      stream: FirebaseService.watchPrescriptions(doctorId: doctorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81))),
          );
        }

        var prescriptions = snapshot.data ?? [];

        if (searchQuery.isNotEmpty) {
          prescriptions = prescriptions.where((p) {
            return p.patientName.toLowerCase().contains(searchQuery) ||
                p.diagnosis.toLowerCase().contains(searchQuery);
          }).toList();
        }

        if (prescriptions.isEmpty) {
          return const _EmptyState(
            icon: Icons.medication_outlined,
            title: 'No Prescriptions Found',
            subtitle: 'Prescriptions created by you will appear here',
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: prescriptions.length,
          itemBuilder: (context, index) {
            return _PrescriptionCard(prescription: prescriptions[index]);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY FEED TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityFeedTab extends StatelessWidget {
  final Set<String> myAshaIds;
  final String searchQuery;

  const _ActivityFeedTab({
    required this.myAshaIds,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityLog>>(
      stream: FirebaseService.watchActivityLogs(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81))),
          );
        }

        final rawLogs = snapshot.data ?? [];
        var logs = rawLogs.where((l) => myAshaIds.contains(l.userId)).toList();

        if (searchQuery.isNotEmpty) {
          logs = logs.where((l) {
            return l.description.toLowerCase().contains(searchQuery) ||
                l.userName.toLowerCase().contains(searchQuery);
          }).toList();
        }

        if (logs.isEmpty) {
          return const _EmptyState(
            icon: Icons.history_rounded,
            title: 'No Activity Yet',
            subtitle: 'ASHA, doctor, and patient actions will log here',
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: log.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(log.icon, color: log.color, size: 20),
                ),
                title: Text(
                  log.description,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                subtitle: Text(
                  '${log.userName} (${log.userRole.toUpperCase()}) • ${log.formattedTime}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ),
            );
          },
        );
      },
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  child: Text(
                    prescription.patientName.isNotEmpty
                        ? prescription.patientName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF8B5CF6),
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
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(
                        'Dr. ${prescription.doctorName} • ${prescription.formattedDate}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: prescription.isActive
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: prescription.isActive
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    prescription.status.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: prescription.isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Diagnosis: ${prescription.diagnosis}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (prescription.medications.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: prescription.medications.map((med) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getMedIcon(med.type),
                            size: 14, color: const Color(0xFF8B5CF6)),
                        const SizedBox(width: 4),
                        Text(
                          '${med.name} (${med.dosage})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE WIDGET
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
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
