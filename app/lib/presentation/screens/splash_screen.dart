import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    Future.delayed(const Duration(seconds: 2), _routeNext);
  }

  Future<void> _routeNext() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (!mounted) return;
    if (session == null) {
      context.go('/auth/role');
      return;
    }

    final profile = await Supabase.instance.client
        .from('user_profiles')
        .select('role, must_change_password, is_active')
        .eq('id', session.user.id)
        .maybeSingle();

    if (!mounted) return;

    if (profile == null || profile['is_active'] == false) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go('/auth/login');
      return;
    }

    if (profile['must_change_password'] == true) {
      context.go('/auth/change-password');
      return;
    }

    switch ((profile['role'] as String?) ?? 'asha') {
      case 'doctor':
        context.go('/dashboard/doctor');
        break;
      case 'admin':
        context.go('/admin');
        break;
      default:
        context.go('/dashboard/asha');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 64,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'ASHA Saathi AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ASHA Bolegi • AI Sunegi • Doctor Janega',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 60),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
