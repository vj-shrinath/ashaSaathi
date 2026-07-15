import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/patient_card.dart';

class AshaDashboardScreen extends StatelessWidget {
  const AshaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // In production, fetch this list via Riverpod wrapping Firestore
    final dummyPatients = [
      {'id': 'p1', 'name': 'Sita Devi', 'age': 45, 'village': 'Rampur', 'risk': 'Green'},
      {'id': 'p2', 'name': 'Ramesh Kumar', 'age': 65, 'village': 'Rampur', 'risk': 'Yellow'},
      {'id': 'p3', 'name': 'Kavita', 'age': 28, 'village': 'Shivpur', 'risk': 'Orange'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASHA Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Offline Data',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {},
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Trigger Riverpod provider refresh
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _DashboardStat(label: 'Assigned', value: '142', color: Theme.of(context).colorScheme.primary),
                        _DashboardStat(label: 'Pending', value: '12', color: Colors.orange),
                        _DashboardStat(label: 'Critical', value: '3', color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  'My Patients',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final pt = dummyPatients[index];
                  return PatientCard(
                    name: pt['name'] as String,
                    age: pt['age'] as int,
                    village: pt['village'] as String,
                    riskCategory: pt['risk'] as String,
                    onTap: () => context.push('/patient/${pt['id']}'),
                  );
                },
                childCount: dummyPatients.length,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Flow to add new patient
        },
        icon: const Icon(Icons.add),
        label: const Text('New Patient'),
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DashboardStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}
