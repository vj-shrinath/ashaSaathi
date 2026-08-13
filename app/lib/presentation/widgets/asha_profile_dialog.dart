import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AshaProfileDialog extends StatefulWidget {
  const AshaProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AshaProfileDialog(),
    );
  }

  @override
  State<AshaProfileDialog> createState() => _AshaProfileDialogState();
}

class _AshaProfileDialogState extends State<AshaProfileDialog> {
  bool _isLoading = true;
  String? _errorMessage;

  String _fullName = 'ASHA Worker';
  String _email = 'N/A';
  String _phone = 'N/A';
  String _phcName = 'Not Assigned';
  String _phcLocation = '';
  String _doctorName = 'Not Assigned';
  String _userId = '';
  int _totalPatients = 0;
  int _urgentCases = 0;
  int _totalRegisters = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No active session found';
          });
        }
        return;
      }

      _userId = user.id;
      _email = user.email ?? 'N/A';

      // Determine phone number cleanly
      final metaPhone = user.userMetadata?['phone'] as String? ??
          user.userMetadata?['whatsapp_number'] as String?;
      if (user.phone != null && user.phone!.isNotEmpty) {
        _phone = user.phone!;
      } else if (metaPhone != null && metaPhone.isNotEmpty) {
        _phone = metaPhone;
      } else {
        _phone = _email;
      }

      // 1. Fetch user_profiles row
      final profileRow = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, phc_id, doctor_id, role')
          .eq('id', user.id)
          .maybeSingle();

      if (profileRow != null) {
        final dbName = profileRow['full_name'] as String?;
        if (dbName != null && dbName.isNotEmpty) {
          _fullName = dbName;
        } else {
          _fullName = user.userMetadata?['full_name'] as String? ?? 'ASHA Worker';
        }

        final phcId = profileRow['phc_id'] as String?;
        final doctorId = profileRow['doctor_id'] as String?;

        // Fetch PHC details
        if (phcId != null && phcId.isNotEmpty) {
          final phcRow = await Supabase.instance.client
              .from('phcs')
              .select('name, district, taluka')
              .eq('id', phcId)
              .maybeSingle();

          if (phcRow != null) {
            _phcName = phcRow['name'] as String? ?? 'Primary Health Centre';
            final dist = phcRow['district'] as String?;
            final tal = phcRow['taluka'] as String?;
            if (dist != null || tal != null) {
              _phcLocation = [tal, dist].whereType<String>().join(', ');
            }
          }
        }

        // Fetch Supervising Doctor details
        if (doctorId != null && doctorId.isNotEmpty) {
          final docRow = await Supabase.instance.client
              .from('user_profiles')
              .select('full_name')
              .eq('id', doctorId)
              .maybeSingle();

          if (docRow != null && docRow['full_name'] != null) {
            _doctorName = 'Dr. ${docRow['full_name']}';
          }
        }
      } else {
        _fullName = user.userMetadata?['full_name'] as String? ?? 'ASHA Worker';
      }

      // 2. Fetch patient metrics
      try {
        final patientsRes = await Supabase.instance.client
            .from('patients')
            .select('id, risk_category')
            .eq('asha_id', user.id);

        final patientList = patientsRes as List<dynamic>;
        _totalPatients = patientList.length;
        _urgentCases = patientList.where((p) {
          final risk = p['risk_category'] as String?;
          return risk == 'Red' || risk == 'Orange';
        }).length;
      } catch (_) {
        // Fallback silently if patients table query is constrained by RLS
      }

      // 3. Fetch registers count
      try {
        final regRes = await Supabase.instance.client
            .from('gramnidan_registers')
            .select('id')
            .eq('asha_id', user.id);

        _totalRegisters = (regRes as List<dynamic>).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading profile: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: isDark ? const Color(0xFF131D24) : Colors.white,
            child: _isLoading
                ? const SizedBox(
                    height: 280,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF2D6A4F)),
                          SizedBox(height: 16),
                          Text(
                            'Fetching ASHA Profile...',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── 1. HERO HEADER ─────────────────────────────────────
                        _buildHeroHeader(context),

                        // ── 2. IMPACT METRICS BAR ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: _buildImpactMetrics(context),
                        ),

                        // ── 3. DETAILED INFORMATION SECTIONS ──────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(context, 'WORK & FACILITY DETAILS'),
                              const SizedBox(height: 8),
                              _buildCardContainer(
                                isDark: isDark,
                                children: [
                                  _buildDetailRow(
                                    context,
                                    icon: Icons.location_city_rounded,
                                    label: 'Primary Health Centre (PHC)',
                                    value: _phcName,
                                    subValue: _phcLocation.isNotEmpty ? _phcLocation : null,
                                  ),
                                  const Divider(height: 16),
                                  _buildDetailRow(
                                    context,
                                    icon: Icons.medical_services_rounded,
                                    label: 'Supervising Medical Officer',
                                    value: _doctorName,
                                  ),
                                  const Divider(height: 16),
                                  _buildDetailRow(
                                    context,
                                    icon: Icons.phone_android_rounded,
                                    label: 'Mobile Number',
                                    value: _phone,
                                  ),
                                  const Divider(height: 16),
                                  _buildDetailRow(
                                    context,
                                    icon: Icons.email_outlined,
                                    label: 'Email Account',
                                    value: _email,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              _buildSectionTitle(context, 'ACCOUNT & DEVICE SECURITY'),
                              const SizedBox(height: 8),
                              _buildCardContainer(
                                isDark: isDark,
                                children: [
                                  _buildDetailRow(
                                    context,
                                    icon: Icons.fingerprint_rounded,
                                    label: 'Biometric Status',
                                    value: 'Bound to Device',
                                    trailingBadge: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'SECURE',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 16),
                                  _buildDetailRow(
                                    context,
                                    icon: Icons.badge_outlined,
                                    label: 'Profile ID',
                                    value: _userId.length > 16
                                        ? '${_userId.substring(0, 16)}...'
                                        : _userId,
                                    onCopy: () {
                                      Clipboard.setData(ClipboardData(text: _userId));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Profile ID copied to clipboard'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── 4. QUICK ACTIONS BAR ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        context.push('/auth/change-password');
                                      },
                                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                                      label: const Text('Change Password'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2D6A4F),
                                        side: const BorderSide(color: Color(0xFF2D6A4F)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await Supabase.instance.client.auth.signOut();
                                        if (context.mounted) {
                                          context.go('/auth/login');
                                        }
                                      },
                                      icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                                      label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.red.shade300),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2D6A4F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'Back to Patients',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Hero Header ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B4332), // Deep Forest Green
            Color(0xFF2D6A4F), // Emerald Health
            Color(0xFF40916C), // Vibrant Mint Green
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 24),
      child: Column(
        children: [
          // Close button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'OFFICIAL PROFILE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Avatar with Active Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF52B788),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Verified ASHA Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFFD8F3DC), size: 15),
                SizedBox(width: 6),
                Text(
                  'ASHA Worker • Swasthya Saathi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Impact Metrics Row ───────────────────────────────────────────────────────
  Widget _buildImpactMetrics(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricColumn(
            icon: Icons.people_rounded,
            count: '$_totalPatients',
            label: 'Patients',
            color: const Color(0xFF1B4332),
          ),
          Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
          _buildMetricColumn(
            icon: Icons.assignment_turned_in_rounded,
            count: '$_totalRegisters',
            label: 'Registers',
            color: const Color(0xFF2D6A4F),
          ),
          Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
          _buildMetricColumn(
            icon: Icons.warning_amber_rounded,
            count: '$_urgentCases',
            label: 'Urgent Cases',
            color: _urgentCases > 0 ? Colors.red[700]! : Colors.grey[700]!,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Detail Components ───────────────────────────────────────────────────────
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white60
            : Colors.grey[700],
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2C35) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    Widget? trailingBadge,
    VoidCallback? onCopy,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2D6A4F)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(height: 1),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailingBadge,
        if (onCopy != null) ...[
          IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: Color(0xFF2D6A4F),
            ),
            onPressed: onCopy,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            tooltip: 'Copy',
          ),
        ],
      ],
    );
  }
}
