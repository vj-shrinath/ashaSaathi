import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/activity_log.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/backend_api_service.dart';
import '../widgets/app_error_banner.dart';

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
            Tab(text: 'PHC SETUP'),
            Tab(text: 'USERS'),
            Tab(text: 'PHC ADMIN'),
            Tab(text: 'ACTIVITY LOGS'),
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
          const _PhcSetupTab(),
          const _WorkerManagementTab(),
          const _PhcAdminSetupTab(),
          _AllActivityLogsTab(),
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

class _PhcSetupTab extends StatefulWidget {
  const _PhcSetupTab();

  @override
  State<_PhcSetupTab> createState() => _PhcSetupTabState();
}

class _PhcSetupTabState extends State<_PhcSetupTab> {
  final _nameController = TextEditingController();
  final _districtController = TextEditingController();
  final _talukaController = TextEditingController();
  final _villageController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _createdPhc;
  List<Map<String, dynamic>> _phcs = [];
  Map<String, dynamic>? _editingPhc;

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _talukaController.dispose();
    _villageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPhcs();
  }

  Future<void> _loadPhcs() async {
    setState(() => _isLoading = true);
    try {
      final items = await BackendApiService.listPhcs();
      if (!mounted) return;
      setState(() {
        _phcs = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _fillForm(Map<String, dynamic> phc) {
    setState(() {
      _editingPhc = phc;
      _nameController.text = phc['name'] as String? ?? '';
      _districtController.text = phc['district'] as String? ?? '';
      _talukaController.text = phc['taluka'] as String? ?? '';
      _villageController.text = phc['village'] as String? ?? '';
      _addressController.text = phc['address'] as String? ?? '';
      _error = null;
      _createdPhc = null;
    });
  }

  void _clearForm() {
    setState(() {
      _editingPhc = null;
      _nameController.clear();
      _districtController.clear();
      _talukaController.clear();
      _villageController.clear();
      _addressController.clear();
      _error = null;
      _createdPhc = null;
    });
  }

  Future<void> _createPhc() async {
    final name = _nameController.text.trim();
    final district = _districtController.text.trim();
    final taluka = _talukaController.text.trim();
    final village = _villageController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || district.isEmpty || taluka.isEmpty || village.isEmpty || address.isEmpty) {
      setState(() => _error = 'All PHC details are required');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _createdPhc = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _error = 'Admin session expired. Please re-login.';
          _isSaving = false;
        });
        return;
      }

      final phc = _editingPhc == null
          ? await BackendApiService.createPhc(
              name: name,
              district: district,
              taluka: taluka,
              village: village,
              address: address,
              adminToken: session.accessToken,
            )
          : await BackendApiService.updatePhc(
              phcId: _editingPhc!['id'] as String,
              name: name,
              district: district,
              taluka: taluka,
              village: village,
              address: address,
              adminToken: session.accessToken,
            );

      if (!mounted) return;
      setState(() {
        _createdPhc = phc;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
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
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_hospital_outlined, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _editingPhc == null ? 'Create PHC' : 'Edit PHC',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_editingPhc != null)
                        TextButton(
                          onPressed: _clearForm,
                          child: const Text('Cancel Edit'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create the primary health center first. Doctors and ASHAs will be attached to this PHC.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'PHC Name', prefixIcon: Icon(Icons.local_hospital_outlined))),
                  const SizedBox(height: 16),
                  TextField(controller: _talukaController, decoration: const InputDecoration(labelText: 'Taluka', prefixIcon: Icon(Icons.account_tree_outlined))),
                  const SizedBox(height: 16),
                  TextField(controller: _districtController, decoration: const InputDecoration(labelText: 'District', prefixIcon: Icon(Icons.map_outlined))),
                  const SizedBox(height: 16),
                  TextField(controller: _villageController, decoration: const InputDecoration(labelText: 'Village', prefixIcon: Icon(Icons.location_on_outlined))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'PHC Address',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.home_work_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    AppErrorBanner(errorText: _error!),
                    const SizedBox(height: 12),
                  ],
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : FilledButton.icon(
                          onPressed: _createPhc,
                          icon: Icon(_editingPhc == null ? Icons.add_business_outlined : Icons.save_outlined),
                          label: Text(_editingPhc == null ? 'Create PHC' : 'Update PHC'),
                        ),
                  if (_createdPhc != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Saved: ${_createdPhc!['name']} | Code: ${_createdPhc!['code']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Existing PHCs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _loadPhcs,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (_phcs.isEmpty)
                    Text('No PHCs found yet.', style: TextStyle(color: Colors.grey[600]))
                  else
                    ..._phcs.map((phc) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               children: [
                                 Expanded(
                                   child: Text(
                                     (phc['name'] as String? ?? 'PHC').trim(),
                                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                     overflow: TextOverflow.ellipsis,
                                     maxLines: 1,
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: Text(
                                     phc['code'] as String? ?? '',
                                     style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                     overflow: TextOverflow.ellipsis,
                                     maxLines: 1,
                                     textAlign: TextAlign.end,
                                   ),
                                 ),
                               ],
                             ),
                            const SizedBox(height: 6),
                            Text(
                              '${phc['district'] ?? ''} > ${phc['taluka'] ?? ''} > ${phc['village'] ?? ''}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phc['address'] as String? ?? '',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _fillForm(phc),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
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
class _PhcAdminSetupTab extends StatefulWidget {
  const _PhcAdminSetupTab();

  @override
  State<_PhcAdminSetupTab> createState() => _PhcAdminSetupTabState();
}

class _PhcAdminSetupTabState extends State<_PhcAdminSetupTab> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedPhcId;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _createdAdmin;
  List<Map<String, dynamic>> _phcs = [];

  @override
  void initState() {
    super.initState();
    _loadPhcs();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPhcs() async {
    setState(() => _isLoading = true);
    try {
      final items = await BackendApiService.listPhcs();
      if (!mounted) return;
      setState(() {
        _phcs = items;
        _selectedPhcId ??= items.isNotEmpty ? items.first['id'] as String? : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _createAdmin() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final phcId = _selectedPhcId;

    if (fullName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty || phcId == null) {
      setState(() => _error = 'Select a PHC and fill all admin details');
      return;
    }

    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid admin email address');
      return;
    }

    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Password should be at least 6 characters');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _createdAdmin = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _error = 'Admin session expired. Please re-login.';
          _isSaving = false;
        });
        return;
      }

      final admin = await BackendApiService.registerPhcAdmin(
        email: email,
        phone: phone,
        password: password,
        fullName: fullName,
        phcId: phcId,
        adminToken: session.accessToken,
      );

      if (!mounted) return;
      setState(() {
        _createdAdmin = admin;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
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
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Create PHC Admin',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadPhcs,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Reload PHCs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Register the first admin for a PHC. This admin stays scoped to that center and can later add doctors and ASHAs under the same PHC.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPhcId,
                      isExpanded: true,
                      items: _phcs
                          .map(
                            (phc) => DropdownMenuItem<String>(
                              value: phc['id'] as String?,
                              child: Text(
                                '${phc['name'] ?? 'PHC'} (${phc['code'] ?? ''})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _selectedPhcId = value),
                      decoration: const InputDecoration(
                        labelText: 'Select PHC',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Full Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Admin Login Email',
                        hintText: 'admin@yourorganization.org',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Admin Phone Number',
                        counterText: '',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Temporary Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      AppErrorBanner(errorText: _error!),
                      const SizedBox(height: 12),
                    ],
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : FilledButton.icon(
                            onPressed: _createAdmin,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Create PHC Admin'),
                          ),
                  ],
                ],
              ),
            ),
          ),
          if (_createdAdmin != null) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Created',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'Login email: ${_createdAdmin!['email'] ?? '${_phoneController.text.trim()}@gmail.com'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text('User ID: ${_createdAdmin!['user_id'] ?? ''}'),
                    Text('PHC ID: ${_createdAdmin!['phc_id'] ?? ''}'),
                    Text('Already existed: ${_createdAdmin!['existed'] == true ? 'Yes' : 'No'}'),
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

class _WorkerManagementTab extends StatefulWidget {
  const _WorkerManagementTab();

  @override
  State<_WorkerManagementTab> createState() => _WorkerManagementTabState();
}

class _WorkerManagementTabState extends State<_WorkerManagementTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _role = 'asha';
  String? _phcId;
  String? _doctorId;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _created;
  List<Map<String, dynamic>> _phcs = [];
  List<Map<String, dynamic>> _doctors = [];

  @override
  void initState() {
    super.initState();
    _loadPhcs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadPhcs() async {
    setState(() => _loading = true);
    try {
      final phcs = await BackendApiService.listPhcs();
      if (!mounted) return;
      setState(() {
        _phcs = phcs;
        _phcId ??= phcs.isNotEmpty ? phcs.first['id'] as String? : null;
        _loading = false;
      });
      await _loadDoctors();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadDoctors() async {
    final phcId = _phcId;
    if (phcId == null) return;
    try {
      final doctors = await BackendApiService.listDoctorsByPhc(phcId: phcId);
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _doctorId = null;
      });
    } catch (_) {
      if (mounted) setState(() => _doctors = []);
    }
  }

  Future<void> _createWorker() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty || email.isEmpty || _phcId == null) {
      setState(() => _error = 'Select a PHC and enter the full name and email');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _created = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Admin session expired. Please re-login.');
      final result = await BackendApiService.createWorkerAccount(
        email: email,
        fullName: name,
        role: _role,
        phcId: _phcId,
        doctorId: _role == 'asha' ? _doctorId : null,
        adminToken: session.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _created = result;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, color: Color(0xFF6A1B9A)),
                  SizedBox(width: 12),
                  Text('Worker Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Create or reset ASHA and Doctor accounts. The generated temporary password is shown only once.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  items: const [
                    DropdownMenuItem(value: 'asha', child: Text('ASHA Worker')),
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  ],
                  onChanged: (value) => setState(() => _role = value ?? 'asha'),
                  decoration: const InputDecoration(labelText: 'Account Role', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _phcId,
                  isExpanded: true,
                  items: _phcs.map((phc) => DropdownMenuItem<String>(
                    value: phc['id'] as String?,
                    child: Text('${phc['name'] ?? 'PHC'} (${phc['code'] ?? ''})', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => _phcId = value);
                    _loadDoctors();
                  },
                  decoration: const InputDecoration(labelText: 'PHC', prefixIcon: Icon(Icons.local_hospital_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                ),
                if (_role == 'asha' && _doctors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _doctorId,
                    isExpanded: true,
                    items: _doctors.map((doctor) => DropdownMenuItem<String>(
                      value: doctor['id'] as String?,
                      child: Text(doctor['full_name'] as String? ?? 'Doctor', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (value) => setState(() => _doctorId = value),
                    decoration: const InputDecoration(labelText: 'Supervising Doctor (optional)', prefixIcon: Icon(Icons.medical_services_outlined)),
                  ),
                ],
                const SizedBox(height: 16),
                if (_error != null) ...[
                  AppErrorBanner(errorText: _error!),
                  const SizedBox(height: 12),
                ],
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton.icon(
                        onPressed: _createWorker,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Create / Reset Account'),
                      ),
              ],
              if (_created != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _created!['existed'] == true
                        ? '✅ Account successfully RESET\nEmail: ${_emailController.text.trim()}\nNew Temporary PIN: ${_created!['temp_password'] ?? ''}\nThe user must change this PIN after first login.'
                        : '✅ New account CREATED\nEmail: ${_emailController.text.trim()}\nTemporary PIN: ${_created!['temp_password'] ?? ''}\nThe user must change this PIN after first login.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
