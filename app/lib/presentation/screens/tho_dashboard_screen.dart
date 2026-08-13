import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/gramnidan_register.dart';
import '../../core/services/firebase_service.dart';

class ThoDashboardScreen extends StatefulWidget {
  const ThoDashboardScreen({super.key});

  @override
  State<ThoDashboardScreen> createState() => _ThoDashboardScreenState();
}

class _ThoDashboardScreenState extends State<ThoDashboardScreen> {
  // ── Color Palette (Executive Medical Officer Theme) ─────────────────────────
  static const _kDarkSlate = Color(0xFF0F172A);
  static const _kDeepNavy = Color(0xFF1E3A8A);
  static const _kAccentBlue = Color(0xFF2563EB);
  static const _kBgCanvas = Color(0xFFF8FAFC);
  static const _kCardBorder = Color(0xFFE2E8F0);

  String _filter = 'all'; // 'all', 'submitted', 'flagged'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to sign out from the THO Panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/auth/role');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final officerEmail = user?.email ?? 'tho.officer@health.gov.in';

    return Scaffold(
      backgroundColor: _kBgCanvas,
      body: SafeArea(
        child: StreamBuilder<List<GramNidanRegister>>(
          stream: FirebaseService.watchThoInbox(filter: 'all'),
          builder: (context, snapshot) {
            final allRegisters = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            // Calculate metric stats
            final totalCount = allRegisters.length;
            final flaggedCount = allRegisters.where((r) => r.isWarning).length;
            final submittedCount = allRegisters.where((r) => r.submittedToTho).length;
            final now = DateTime.now();
            final todayCount = allRegisters.where((r) {
              return r.createdAt.year == now.year &&
                  r.createdAt.month == now.month &&
                  r.createdAt.day == now.day;
            }).length;

            // Apply active filter
            List<GramNidanRegister> filteredList = allRegisters;
            if (_filter == 'submitted') {
              filteredList = filteredList.where((r) => r.submittedToTho).toList();
            } else if (_filter == 'flagged') {
              filteredList = filteredList.where((r) => r.isWarning).toList();
            }

            // Apply search query
            if (_searchQuery.trim().isNotEmpty) {
              final query = _searchQuery.trim().toLowerCase();
              filteredList = filteredList.where((r) {
                final name = r.effectivePatientName.toLowerCase();
                final type = r.displayName.toLowerCase();
                final asha = r.ashaId.toLowerCase();
                return name.contains(query) || type.contains(query) || asha.contains(query);
              }).toList();
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              color: _kAccentBlue,
              child: CustomScrollView(
                slivers: [
                  // ── 1. Hero Header ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildHeader(officerEmail),
                  ),

                  // ── 2. Metric Overview Bar ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildMetricsGrid(
                        total: totalCount,
                        flagged: flaggedCount,
                        submitted: submittedCount,
                        today: todayCount,
                      ),
                    ),
                  ),

                  // ── 3. Search & Filter Bar ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          _buildFilterTabs(
                            totalCount: totalCount,
                            submittedCount: submittedCount,
                            flaggedCount: flaggedCount,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 4. Main Register List ──────────────────────────────────
                  if (isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: _kAccentBlue),
                            SizedBox(height: 16),
                            Text(
                              'Syncing live block registers...',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (filteredList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final register = filteredList[index];
                            return _ThoInboxCard(
                              register: register,
                              onTap: () => context.push('/dashboard/tho/register/${register.id}'),
                            );
                          },
                          childCount: filteredList.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(String email) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDarkSlate, _kDeepNavy, _kAccentBlue],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.account_balance_rounded, color: Colors.amber, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THO Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Taluka Health Officer • Public Health Monitoring',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white70),
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }

  // ── Metrics Grid ───────────────────────────────────────────────────────────
  Widget _buildMetricsGrid({
    required int total,
    required int flagged,
    required int submitted,
    required int today,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'Total Registers',
            value: '$total',
            icon: Icons.folder_special_rounded,
            color: const Color(0xFF2563EB),
            isSelected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'Submitted',
            value: '$submitted',
            icon: Icons.verified_rounded,
            color: const Color(0xFF10B981),
            isSelected: _filter == 'submitted',
            onTap: () => setState(() => _filter = 'submitted'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'Flagged Alerts',
            value: '$flagged',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444),
            isSelected: _filter == 'flagged',
            onTap: () => setState(() => _filter = 'flagged'),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : _kCardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search patient name, register type, or ASHA ID...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _kAccentBlue, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  // ── Filter Tabs ────────────────────────────────────────────────────────────
  Widget _buildFilterTabs({
    required int totalCount,
    required int submittedCount,
    required int flaggedCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterTabChip('all', 'All ($totalCount)', Icons.dashboard_rounded),
          const SizedBox(width: 8),
          _buildFilterTabChip('submitted', 'Submitted ($submittedCount)', Icons.verified_user_rounded),
          const SizedBox(width: 8),
          _buildFilterTabChip('flagged', 'Flagged ($flaggedCount)', Icons.warning_amber_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterTabChip(String value, String label, IconData icon) {
    final isSelected = _filter == value;
    final color = value == 'flagged'
        ? const Color(0xFFEF4444)
        : (value == 'submitted' ? const Color(0xFF10B981) : _kAccentBlue);

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : _kCardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kAccentBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, size: 40, color: _kAccentBlue),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Registers Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No registers match your search query "$_searchQuery".'
                  : 'No registers available under the selected filter view.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            if (_searchQuery.isNotEmpty || _filter != 'all') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _filter = 'all';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccentBlue,
                  side: const BorderSide(color: _kAccentBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Inbox Card Component ──────────────────────────────────────────────────────
class _ThoInboxCard extends StatelessWidget {
  final GramNidanRegister register;
  final VoidCallback onTap;

  const _ThoInboxCard({required this.register, required this.onTap});

  Color _getBadgeColor() {
    if (register.isWarning) return const Color(0xFFEF4444);
    switch (register.registerType) {
      case 'pregnancy':
      case 'anc':
        return const Color(0xFFEC4899);
      case 'newborn':
      case 'hbnc':
      case 'hbyc':
        return const Color(0xFF0284C7);
      case 'child':
        return const Color(0xFF10B981);
      case 'cbac':
      case 'bpsugar':
      case 'ncd':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getBadgeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: register.isWarning ? Colors.red.shade300 : const Color(0xFFE2E8F0),
          width: register.isWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: register.isWarning
                ? Colors.red.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Icon + Title + Status Badges ───────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(register.icon, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            register.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            register.effectivePatientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (register.isWarning)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red),
                                SizedBox(width: 3),
                                Text(
                                  'FLAGGED',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (register.submittedToTho)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                                SizedBox(width: 3),
                                Text(
                                  'SUBMITTED',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimeAgo(register.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // ── Bottom Info Row ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'ASHA ID: ${register.ashaId.length > 8 ? register.ashaId.substring(0, 8) : register.ashaId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${register.filledModuleCount} modules • ${register.totalFieldsFilled} fields',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
