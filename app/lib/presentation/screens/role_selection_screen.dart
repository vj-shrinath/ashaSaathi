import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isSaving = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _selectRole(String role) async {
    if (_supabase.auth.currentUser == null) {
      context.go('/auth/login/$role');
      return;
    }

    setState(() => _isSaving = true);
    await _supabase.auth.updateUser(
      UserAttributes(
        data: {'role': role},
      ),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    switch (role) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'Select Your Role',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to demo the app',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 48),
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else ...[
                _RoleCard(
                  icon: Icons.medical_services_rounded,
                  title: 'ASHA Worker',
                  subtitle: 'Record patient visits and voice notes',
                  color: const Color(0xFF2E7D32),
                  onTap: () => _selectRole('asha'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.local_hospital_rounded,
                  title: 'Doctor',
                  subtitle: 'View alerts and patient medical history',
                  color: const Color(0xFF0277BD),
                  onTap: () => _selectRole('doctor'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Admin',
                  subtitle: 'Manage districts, workers and reports',
                  color: const Color(0xFF6A1B9A),
                  onTap: () => _selectRole('admin'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
