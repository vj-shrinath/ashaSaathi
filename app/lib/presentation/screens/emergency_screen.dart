import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmergencyScreen extends StatelessWidget {
  final String patientId;
  const EmergencyScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMERGENCY PROTOCOL'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Critical Risk Detected',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Doctor and Family have been notified automatically via SMS and Emergency Alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            // Mock map placeholder for routing to PHC
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey),
              ),
              child: const Center(
                child: Text('Google Maps API Integration\nRouting to Nearest PHC/CHC', textAlign: TextAlign.center),
              ),
            ),
            
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                // url_launcher to call 108
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dialing 108...')));
              },
              icon: const Icon(Icons.call, size: 28),
              label: const Text('DISPATCH 108 AMBULANCE', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/dashboard/asha'),
              child: const Text('Acknowledge and Return to Dashboard'),
            )
          ],
        ),
      ),
    );
  }
}
