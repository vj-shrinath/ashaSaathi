import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/backend_api_service.dart';
import '../widgets/app_error_banner.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _savePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.length != 6 || int.tryParse(password) == null) {
      setState(() => _error = 'PIN must be exactly 6 digits / PIN 6 ank ka hona chahiye');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'PINs do not match / PIN match nahi ho raha');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      final session = _supabase.auth.currentSession;
      if (user == null) {
        context.go('/auth/login');
        return;
      }
      if (session == null) {
        context.go('/auth/login');
        return;
      }

      await BackendApiService.completePasswordChange(
        newPassword: password,
        accessToken: session.accessToken,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
          title: const Text('PIN Set / PIN Tayaar'),
          content: const Text(
            'Your 6-digit PIN was set successfully. Please sign in again with your new PIN.\nAapka 6 ank ka PIN set ho gaya. Naya PIN se login karein.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      await _supabase.auth.signOut();
      if (mounted) context.go('/auth/login');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Password update failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10261C), Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.pin_rounded, size: 56, color: Color(0xFF1B5E20)),
                        const SizedBox(height: 16),
                        Text(
                          'Set Your 6-Digit PIN',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '6 ank ka PIN set karein',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your account requires a new 6-digit PIN before you can continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'New 6-digit PIN / Naya 6 ank ka PIN',
                            prefixIcon: Icon(Icons.pin_outlined),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Confirm PIN / PIN dubara dalein',
                            prefixIcon: Icon(Icons.pin_outlined),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_error != null) ...[
                          AppErrorBanner(errorText: _error!),
                          const SizedBox(height: 16),
                        ],
                        _isSaving
                            ? const Center(child: CircularProgressIndicator())
                            : FilledButton(
                                onPressed: _savePassword,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Save PIN / PIN Save Karein'),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
