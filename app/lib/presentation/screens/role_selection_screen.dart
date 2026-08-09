import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/user_role.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  void _selectRole(UserRole role) {
    context.go('/auth/login?role=${role.value}');
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
                'Choose your role to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 48),
              for (final role in UserRole.values)
                _RoleCard(
                  icon: _iconFor(role),
                  title: role.displayName,
                  subtitle: _subtitleFor(role),
                  color: const Color(0xFF2E7D32),
                  onTap: () => _selectRole(role),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(UserRole role) {
    switch (role) {
      case UserRole.asha:
        return Icons.health_and_safety_rounded;
      case UserRole.doctor:
        return Icons.medical_services_rounded;
      case UserRole.tho:
        return Icons.account_balance_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  String _subtitleFor(UserRole role) {
    switch (role) {
      case UserRole.asha:
        return 'Manage patients and health visits';
      case UserRole.doctor:
        return 'Review patients and prescriptions';
      case UserRole.tho:
        return 'Review ASHA submitted registers';
      case UserRole.admin:
        return 'Manage users and health centers';
    }
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
