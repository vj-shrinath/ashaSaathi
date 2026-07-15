import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/user_role.dart';

class LoginScreen extends StatefulWidget {
  final UserRole? forcedRole;

  const LoginScreen({super.key, this.forcedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  UserRole? _selectedRole;

  SupabaseClient get _supabase => Supabase.instance.client;

  UserRole get _role => widget.forcedRole ?? _selectedRole ?? UserRole.asha;

  bool get _roleIsLocked => widget.forcedRole != null;

  Color get _roleColor {
    switch (_role) {
      case UserRole.asha:
        return const Color(0xFF2E7D32);
      case UserRole.doctor:
        return const Color(0xFF0277BD);
      case UserRole.admin:
        return const Color(0xFF6A1B9A);
    }
  }

  String get _roleDisplayName => _role.displayName;

  String _defaultEmailFor(UserRole role) {
    switch (role) {
      case UserRole.asha:
        return 'test@asha.local';
      case UserRole.doctor:
        return 'doctor@asha.local';
      case UserRole.admin:
        return 'admin@asha.local';
    }
  }

  String _defaultPasswordFor(UserRole role) {
    switch (role) {
      case UserRole.asha:
        return 'Password123!';
      case UserRole.doctor:
        return 'Doctor@12345';
      case UserRole.admin:
        return 'Admin@12345';
    }
  }

  void _chooseRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      _error = null;
      _emailController.text = _defaultEmailFor(role);
      _passwordController.text = _defaultPasswordFor(role);
    });
  }

  bool _isEmailValidForRole(String email, UserRole role) {
    final normalized = email.toLowerCase();
    switch (role) {
      case UserRole.asha:
        return normalized == 'test@asha.local' || normalized.contains('asha');
      case UserRole.doctor:
        return normalized.contains('doctor');
      case UserRole.admin:
        return normalized.contains('admin');
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter email and password');
      return;
    }

    if (_selectedRole == null && widget.forcedRole == null) {
      setState(() => _error = 'Please choose ASHA, Doctor, or Admin first');
      return;
    }

    if (!_isEmailValidForRole(email, _role)) {
      setState(() {
        _error = 'That email does not belong to $_roleDisplayName';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Sign in
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        setState(() {
          _error = 'Authentication failed';
          _isLoading = false;
        });
        return;
      }

      final sessionRole = _getUserRoleFromSession(response.user!);

      if (_roleIsLocked && sessionRole != null && sessionRole != _role) {
        await _supabase.auth.signOut();
        setState(() {
          _error = 'This account is registered as ${sessionRole.displayName}, not $_roleDisplayName';
          _isLoading = false;
        });
        return;
      }

      final effectiveRole = _role;

      // Keep auth metadata aligned with the portal the user selected.
      await _syncAuthRole(effectiveRole);

      if (!mounted) return;
      setState(() => _isLoading = false);
      
      // Navigate to the dashboard for the selected role.
      context.go(effectiveRole.route);
    } on AuthException {
      setState(() {
        _error = widget.forcedRole == null
            ? 'Invalid credentials. Choose your role-specific login if needed.'
            : 'Invalid credentials for $_roleDisplayName';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    } finally {
      if (mounted && !_isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  UserRole? _getUserRoleFromSession(User user) {
    final roleStr = user.userMetadata?['role'] as String?;
    if (roleStr == null || roleStr.isEmpty) return null;
    return UserRole.fromString(roleStr);
  }

  Future<void> _syncAuthRole(UserRole role) async {
    final currentRole = _supabase.auth.currentUser?.userMetadata?['role'] as String?;
    if (currentRole != role.value) {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'role': role.value}),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _roleColor.withValues(alpha: 0.8),
                  _roleColor,
                  _roleColor.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.favorite_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'ASHA Saathi AI',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_roleDisplayName Login',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_roleIsLocked) ...[
                            Text(
                              'Choose your role',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _roleColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _RoleChooser(
                              selectedRole: _selectedRole,
                              onSelected: _chooseRole,
                            ),
                            const SizedBox(height: 20),
                          ],
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
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            '$_roleDisplayName Portal',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _roleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to access your $_roleDisplayName dashboard',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_selectedRole != null || _roleIsLocked) ...[
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined, color: _roleColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _roleColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, color: _roleColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: _roleColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ] else ...[
                            Text(
                              'Pick a role above to continue to login details.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (widget.forcedRole == null) ...[
                            Text(
                              'Choose your portal to sign in with the correct account type.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(color: _roleColor),
                                )
                              : FilledButton(
                                  onPressed: _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _roleColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Sign In as $_roleDisplayName',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                          if (widget.forcedRole == null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Login as different role? ',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/auth/login/asha'),
                                  child: Text(
                                    'ASHA',
                                    style: TextStyle(
                                      color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' / ',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/auth/login/doctor'),
                                  child: Text(
                                    'Doctor',
                                    style: TextStyle(
                                      color: const Color(0xFF0277BD),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' / ',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/auth/login/admin'),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: const Color(0xFF6A1B9A),
                                      fontWeight: FontWeight.bold,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChooser extends StatelessWidget {
  final UserRole? selectedRole;
  final ValueChanged<UserRole> onSelected;

  const _RoleChooser({
    required this.selectedRole,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoleTile(
          role: UserRole.asha,
          selected: selectedRole == UserRole.asha,
          color: const Color(0xFF2E7D32),
          onTap: () => onSelected(UserRole.asha),
        ),
        const SizedBox(height: 12),
        _RoleTile(
          role: UserRole.doctor,
          selected: selectedRole == UserRole.doctor,
          color: const Color(0xFF0277BD),
          onTap: () => onSelected(UserRole.doctor),
        ),
        const SizedBox(height: 12),
        _RoleTile(
          role: UserRole.admin,
          selected: selectedRole == UserRole.admin,
          color: const Color(0xFF6A1B9A),
          onTap: () => onSelected(UserRole.admin),
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(
                  role == UserRole.asha
                      ? Icons.medical_services_rounded
                      : role == UserRole.doctor
                          ? Icons.local_hospital_rounded
                          : Icons.admin_panel_settings_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected ? 'Selected' : 'Tap to continue',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
