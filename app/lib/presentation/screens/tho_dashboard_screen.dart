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
  // ── Colors (Sleek THO palette) ─────────────────────────────────────────────
  final _kIndigo = const Color(0xFF1E3A8A); // text
  final _kOffWhite = const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/auth/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kOffWhite,
      appBar: AppBar(
        title: const Text('THO Control Center', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _kIndigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => _logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: StreamBuilder<List<GramNidanRegister>>(
        stream: FirebaseService.watchThoInbox(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading inbox: ${snapshot.error}'));
          }
          final registers = snapshot.data ?? [];
          if (registers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Inbox is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('No registers submitted by ASHA workers yet.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: registers.length,
              itemBuilder: (context, index) {
                final register = registers[index];
                return _ThoInboxCard(
                  register: register,
                  onTap: () => context.push('/dashboard/tho/register/${register.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ThoInboxCard extends StatelessWidget {
  final GramNidanRegister register;
  final VoidCallback onTap;

  const _ThoInboxCard({required this.register, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: register.isWarning
            ? BorderSide(color: Colors.orange.shade800, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(register.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${register.displayName} - ${register.patientName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'ASHA ID: ${register.ashaId.substring(0, 8)}...',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (register.isWarning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.deepOrange),
                          SizedBox(width: 4),
                          Text('FLAGGED', style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${register.totalFieldsFilled} fields filled',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${register.createdAt.day}/${register.createdAt.month}/${register.createdAt.year} ${register.createdAt.hour}:${register.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
