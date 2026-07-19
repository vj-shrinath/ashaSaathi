import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/models/user_role.dart';
import '../../core/services/biometric_auth_service.dart';
import '../../core/services/backend_api_service.dart';

class LoginScreen extends StatefulWidget {
  final UserRole? forcedRole;

  const LoginScreen({super.key, this.forcedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Biometric state variables
  bool _isBiometricSupported = false;
  bool _isUsingFallback = false;
  bool _isRegisteringBiometric = false;
  bool _needsRecovery = false;
  bool _isAdminRegistering = false;
  String? _registeredName;
  List<Map<String, dynamic>> _phcs = [];
  List<Map<String, dynamic>> _doctors = [];
  String? _selectedPhcId;
  String? _selectedDoctorId;
  bool _isLoadingOrgData = false;

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

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    if (_role == UserRole.admin) {
      if (!mounted) return;
      setState(() {
        _isBiometricSupported = false;
        _registeredName = null;
        _isRegisteringBiometric = false;
        _needsRecovery = false;
        _isUsingFallback = true;
        _selectedPhcId = null;
        _selectedDoctorId = null;
        _isAdminRegistering = false;
      });
      await _loadOrgData();
      return;
    }

    final supported = await BiometricAuthService.isBiometricsSupported();
    final setup = await BiometricAuthService.isRoleBiometricsSetup(_role);
    final regName = await BiometricAuthService.getRegisteredFullName(_role);

    if (!mounted) return;

    setState(() {
      _isBiometricSupported = true;
      _registeredName = regName;
      _isRegisteringBiometric = false;
      _needsRecovery = !setup;
      _isUsingFallback = !supported || !setup;
    });

    // Auto-trigger biometric challenge if fingerprint is already configured locally
    if (setup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loginWithBiometrics();
      });
    }

    await _loadOrgData();
  }

  Future<void> _loadOrgData() async {
    setState(() => _isLoadingOrgData = true);
    try {
      final phcs = await BackendApiService.listPhcs();
      if (!mounted) return;
      setState(() {
        _phcs = phcs;
        _isLoadingOrgData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOrgData = false);
    }
  }

  Future<void> _loadDoctorsForPhc(String phcId) async {
    setState(() {
      _isLoadingOrgData = true;
      _selectedDoctorId = null;
      _doctors = [];
    });
    try {
      final doctors = await BackendApiService.listDoctorsByPhc(phcId: phcId);
      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _isLoadingOrgData = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingOrgData = false);
    }
  }

  Future<void> _loginWithBiometrics() async {
    if (_role == UserRole.admin) {
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authenticated = await BiometricAuthService.authenticate(
        localizedReason: 'Scan fingerprint to access your $_roleDisplayName Portal',
      );

      if (!authenticated) {
        setState(() {
          _error = 'Biometric scan failed or cancelled';
          _isLoading = false;
        });
        return;
      }

      final credentials = await BiometricAuthService.getCredentials(_role);
      if (credentials == null) {
        setState(() {
          _error = 'Credentials not found. Please register fingerprint.';
          _isRegisteringBiometric = true;
          _isLoading = false;
        });
        return;
      }

      final response = await _supabase.auth.signInWithPassword(
        email: credentials['email']!,
        password: credentials['password']!,
      );

      if (response.user == null) {
        setState(() {
          _error = 'Failed to sign in. User might have been deleted.';
          _isLoading = false;
        });
        return;
      }

      await _syncAuthRole(_role);

      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(_role.route);
    } catch (e) {
      setState(() {
        _error = 'Fingerprint Lock Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _registerWithBiometrics() async {
    if (_role == UserRole.admin) {
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your Full Name');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit Phone Number');
      return;
    }
    if (_selectedPhcId == null) {
      setState(() => _error = 'Please select a PHC');
      return;
    }
    if (_role == UserRole.asha && _selectedDoctorId == null) {
      setState(() => _error = 'Please select a supervising doctor');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Authenticate with fingerprint scanner first to verify biometric setup
      final authenticated = await BiometricAuthService.authenticate(
        localizedReason: 'Scan fingerprint to verify biometric lock registration',
      );

      if (!authenticated) {
        setState(() {
          _error = 'Registration cancelled: Fingerprint scan is required';
          _isLoading = false;
        });
        return;
      }

      if (_needsRecovery) {
        await _recoverExistingProfile(phone);
        return;
      }

      // 2. Generate unique email and strong password
      final generatedEmail = '$phone@gmail.com';
      final generatedPassword = const Uuid().v4();

      // 3. Register user profile using Node Backend to bypass confirmation email rate limits
      await BackendApiService.registerWorker(
        phone: phone,
        password: generatedPassword,
        fullName: name,
        role: _role.name,
        phcId: _selectedPhcId!,
        doctorId: _role == UserRole.asha ? _selectedDoctorId : null,
      );

      // 4. Sign in the newly created account
      final response = await _supabase.auth.signInWithPassword(
        email: generatedEmail,
        password: generatedPassword,
      );

      final currentUser = response.user;
      if (currentUser == null) {
        setState(() {
          _error = 'Account created, but automatic sign in failed.';
          _isLoading = false;
        });
        return;
      }

      // 5. Save to secure local storage
      await BiometricAuthService.saveCredentials(
        email: generatedEmail,
        password: generatedPassword,
        role: _role,
        fullName: name,
      );

      await _syncAuthRole(_role);

      if (!mounted) return;
      setState(() {
        _registeredName = name;
        _isRegisteringBiometric = false;
        _isLoading = false;
      });

      // Redirect user to their role-specific dashboard
      context.go(_role.route);

    } on AuthException catch (e) {
      setState(() => _isLoading = false);

      // Supabase returns code 'user_already_exists' or status 422
      // when the phone/email is already registered on another device.
      final isUserAlreadyExists =
          e.statusCode == '422' ||
          e.message.toLowerCase().contains('user already registered') ||
          e.message.toLowerCase().contains('already been registered') ||
          e.message.toLowerCase().contains('already exists');

      if (isUserAlreadyExists) {
        _showSyncPinDialog(_phoneController.text.trim());
      } else {
        setState(() => _error = e.message);
      }

    } catch (e) {
      setState(() {
        _error = 'Registration Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _recoverExistingProfile(String phone) async {
    try {
      final existing = await BackendApiService.resolveWorker(phone: phone);
      final resolvedName = (existing['full_name'] as String?)?.trim();
      final resolvedRole = UserRole.fromString((existing['role'] as String?) ?? _role.value);

      if (resolvedName != null && resolvedName.isNotEmpty) {
        _nameController.text = resolvedName;
      }

      _showSyncPinDialog(phone);

      if (!mounted) return;
      setState(() {
        _registeredName = resolvedName;
        _isRegisteringBiometric = false;
        _isUsingFallback = false;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No existing profile found for this phone. Please register as a new user.';
        _isRegisteringBiometric = true;
        _isLoading = false;
      });
    }
  }

  /// Shows dialog asking if user wants to sync via Admin PIN
  void _showSyncPinDialog(String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1A1A2E),
          title: Row(
            children: [
              Icon(Icons.sync_rounded, color: Colors.amber[400]),
              const SizedBox(width: 12),
              const Text(
                'Device Transfer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This phone number is already registered on another device.',
                style: TextStyle(color: Colors.grey[300], fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                'To transfer your account, ask your Admin for a 6-digit Sync Code.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showPinEntryDialog(phone);
              },
              icon: const Icon(Icons.vpn_key_rounded, size: 18),
              label: const Text('Enter Code'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber[700],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows a dialog to enter the 6-digit sync PIN
  void _showPinEntryDialog(String phone) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            'Enter Sync Code',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the 6-digit code provided by your Admin',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  letterSpacing: 12,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '• • • • • •',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 28, letterSpacing: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin.length == 6) {
                  Navigator.pop(ctx);
                  _syncDeviceWithPin(phone, pin);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green[700]),
              child: const Text('Verify & Transfer'),
            ),
          ],
        );
      },
    );
  }

  /// Performs the actual device sync using the 6-digit PIN
  Future<void> _syncDeviceWithPin(String phone, String pin) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Verify the sync PIN with the backend
      final syncData = await BackendApiService.verifySyncToken(
        phone: phone,
        pin: pin,
      );

      final tempPassword = syncData['temp_password'] as String;
      final fullName = syncData['full_name'] as String? ?? 'ASHA Worker';
      final backendRole = UserRole.fromString(syncData['role'] as String? ?? _role.value);
      final email = '$phone@gmail.com';

      // 2. Sign in with the temporary credentials
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: tempPassword,
      );

      if (response.user == null) {
        setState(() {
          _error = 'Login with sync credentials failed.';
          _isLoading = false;
        });
        return;
      }

      // 3. Rotate the password to a new permanent one
      final newPermanentPassword = const Uuid().v4();
      await _supabase.auth.updateUser(
        UserAttributes(password: newPermanentPassword),
      );

      // 4. Save the new credentials to this device's secure storage
      await BiometricAuthService.saveCredentials(
        email: email,
        password: newPermanentPassword,
        role: backendRole,
        fullName: fullName,
      );

      await _syncAuthRole(backendRole);

      if (!mounted) return;
      setState(() {
        _registeredName = fullName;
        _isRegisteringBiometric = false;
        _isLoading = false;
        _needsRecovery = false;
      });

      // 5. Navigate to the dashboard
      context.go(backendRole.route);

    } catch (e) {
      setState(() {
        _error = 'Sync failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Standard fallback email/password login for admin/doctor/testing
  Future<void> _fallbackLogin() async {
    var email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter email and password');
      return;
    }

    // Support phone number in email field
    if (RegExp(r'^\d{10}$').hasMatch(email)) {
      email = '$email@gmail.com';
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
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

      await _syncAuthRole(_role);

      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(_role.route);
    } on AuthException {
      setState(() {
        _error = 'Invalid credentials for $_roleDisplayName';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _registerAdmin() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your Full Name');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit Phone Number');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      setState(() => _error = 'Password should be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final generatedEmail = '$phone@gmail.com';

      // Register user profile using Node Backend to bypass confirmation email rate limits
      await BackendApiService.registerWorker(
        phone: phone,
        password: password,
        fullName: name,
        role: 'admin',
        phcId: null,
        doctorId: null,
      );

      // Sign in the newly created account
      final response = await _supabase.auth.signInWithPassword(
        email: generatedEmail,
        password: password,
      );

      final currentUser = response.user;
      if (currentUser == null) {
        setState(() {
          _error = 'Admin account created, but automatic sign in failed.';
          _isLoading = false;
        });
        return;
      }

      await _syncAuthRole(UserRole.admin);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Redirect user to admin dashboard
      context.go(UserRole.admin.route);

    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Registration Error: ${e.toString()}';
        _isLoading = false;
      });
    }
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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD METHODS
  // ─────────────────────────────────────────────────────────────

  Widget _buildBiometricLoginFields() {
    if (_role == UserRole.admin) {
      return _buildFallbackLoginFields();
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          _needsRecovery
              ? 'Device Reset Detected'
              : 'Welcome Back${_registeredName != null ? ', $_registeredName' : ''}!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _roleColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _needsRecovery
              ? 'This device no longer has your saved biometric profile. Recover your existing account instead of creating a new one.'
              : 'Place your finger on the scanner to unlock',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _isLoading ? null : _loginWithBiometrics,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_roleColor.withValues(alpha: 0.2), _roleColor.withValues(alpha: 0.05)],
              ),
              border: Border.all(color: _roleColor.withValues(alpha: 0.3), width: 3),
            ),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _roleColor))
                : Icon(Icons.fingerprint_rounded, size: 64, color: _roleColor)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1200.ms)
                    .then()
                    .shimmer(duration: 1500.ms, color: _roleColor.withValues(alpha: 0.3)),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_role != UserRole.admin)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isRegisteringBiometric = true;
                    _needsRecovery = false;
                  });
                },
                icon: Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.grey[600]),
                label: Text(
                  _needsRecovery ? 'Re-register Biometric' : 'Register New Profile',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            TextButton.icon(
              onPressed: () {
                setState(() => _isUsingFallback = true);
              },
              icon: Icon(Icons.email_outlined, size: 16, color: Colors.grey[600]),
              label: Text('Email Login', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBiometricRegistrationFields() {
    if (_role == UserRole.admin) {
      return _buildFallbackLoginFields();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _needsRecovery ? 'Recover Existing Profile' : 'Register Fingerprint Lock',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _roleColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _needsRecovery
              ? 'Enter the same phone number used before app data was cleared. If the account already exists, we will restore access instead of creating a duplicate profile.'
              : 'Create your secure biometric profile for $_roleDisplayName portal.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Full Name',
            hintText: 'e.g. Radha Devi',
            prefixIcon: Icon(Icons.person_outline, color: _roleColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _roleColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '10-digit mobile number',
            counterText: '',
            prefixIcon: Icon(Icons.phone_outlined, color: _roleColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _roleColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _isLoadingOrgData
            ? const LinearProgressIndicator()
            : DropdownButtonFormField<String>(
                value: _selectedPhcId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Select PHC',
                  prefixIcon: Icon(Icons.local_hospital_outlined, color: _roleColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _phcs
                    .map(
                      (phc) => DropdownMenuItem<String>(
                        value: phc['id'] as String,
                        child: Text('${phc['name']} (${phc['code']})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  setState(() => _selectedPhcId = value);
                  if (value != null) {
                    await _loadDoctorsForPhc(value);
                  }
                },
              ),
        if (_role == UserRole.asha) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedDoctorId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Select Doctor',
              prefixIcon: Icon(Icons.medical_services_outlined, color: _roleColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _doctors
                .map(
                  (doctor) => DropdownMenuItem<String>(
                    value: doctor['id'] as String,
                    child: Text(doctor['full_name'] as String? ?? 'Doctor'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedDoctorId = value),
          ),
        ],
        const SizedBox(height: 24),
        // Animated fingerprint icon
        Center(
          child: GestureDetector(
            onTap: _isLoading ? null : _registerWithBiometrics,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_roleColor.withValues(alpha: 0.15), _roleColor.withValues(alpha: 0.05)],
                ),
                border: Border.all(color: _roleColor.withValues(alpha: 0.3), width: 2),
              ),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _roleColor, strokeWidth: 3))
                  : Icon(Icons.fingerprint_rounded, size: 52, color: _roleColor)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1200.ms),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: Text('Registering...', style: TextStyle(color: Colors.grey)))
            : FilledButton.icon(
                onPressed: _registerWithBiometrics,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Scan & Register Profile'),
                style: FilledButton.styleFrom(
                  backgroundColor: _roleColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
        const SizedBox(height: 16),
        if (_role != UserRole.admin)
          TextButton.icon(
            onPressed: () {
              setState(() => _isUsingFallback = true);
            },
            icon: Icon(Icons.email_outlined, size: 16, color: Colors.grey[600]),
            label: Text('Use Email & Password System', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildFallbackLoginFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$_roleDisplayName Login',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _roleColor),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in with phone number or email and password for $_roleDisplayName portal.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Phone Number or Email',
            hintText: 'e.g. 9876543210 or admin@gmail.com',
            prefixIcon: Icon(Icons.email_outlined, color: _roleColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _roleColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _isLoading
            ? Center(child: CircularProgressIndicator(color: _roleColor))
            : FilledButton(
                onPressed: _fallbackLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: _roleColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Sign In as $_roleDisplayName',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
        if (_isBiometricSupported) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              setState(() => _isUsingFallback = false);
            },
            icon: Icon(Icons.fingerprint_rounded, size: 18, color: _roleColor),
            label: Text('Switch to Fingerprint Login', style: TextStyle(color: _roleColor, fontSize: 13)),
          ),
        ],
        if (_role == UserRole.admin) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _isAdminRegistering = true;
                _error = null;
              });
            },
            child: Text(
              'Don\'t have an admin account? Register',
              style: TextStyle(color: _roleColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdminRegistrationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Register Admin Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _roleColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create your admin account. You will log in using your phone number or email and password.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Full Name',
            hintText: 'e.g. Radha Devi',
            prefixIcon: Icon(Icons.person_outline, color: _roleColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _roleColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '10-digit mobile number',
            counterText: '',
            prefixIcon: Icon(Icons.phone_outlined, color: _roleColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            hintText: 'At least 6 characters',
            prefixIcon: Icon(Icons.lock_outline, color: _roleColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _roleColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _isLoading
            ? Center(child: CircularProgressIndicator(color: _roleColor))
            : FilledButton(
                onPressed: _registerAdmin,
                style: FilledButton.styleFrom(
                  backgroundColor: _roleColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Register Admin Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _isAdminRegistering = false;
              _error = null;
            });
          },
          child: Text(
            'Already have an admin account? Sign In',
            style: TextStyle(color: _roleColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    void goBackToRoleSelection() {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/auth/role');
      }
    }

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
                  const Text(
                    'ASHA Saathi AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                              onSelected: (role) {
                                setState(() {
                                  _selectedRole = role;
                                  _error = null;
                                });
                                _initBiometrics();
                              },
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
                          // Render correct state fields dynamically
                          _role == UserRole.admin
                              ? (_isAdminRegistering
                                  ? _buildAdminRegistrationFields()
                                  : _buildFallbackLoginFields())
                              : (_isUsingFallback
                                  ? _buildFallbackLoginFields()
                                  : (_isRegisteringBiometric
                                      ? _buildBiometricRegistrationFields()
                                      : _buildBiometricLoginFields())),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: Material(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: goBackToRoleSelection,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
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
