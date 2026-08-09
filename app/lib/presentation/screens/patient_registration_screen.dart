import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/activity_log.dart';
import '../../core/models/patient_model.dart';
import '../../core/services/firebase_service.dart';

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  State<PatientRegistrationScreen> createState() => _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _registerScrollController = ScrollController();

  final _registerOptions = const [
    _RegisterOption('patient', 'Patient', Icons.person_rounded, 'General patient chat'),
    _RegisterOption('pregnancy', 'Pregnancy', Icons.pregnant_woman_rounded, 'ANC Tracking Register'),
    _RegisterOption('newborn', 'Newborn', Icons.baby_changing_station_rounded, 'HBNC Register (0-28 days)'),
    _RegisterOption('child', 'Child Health', Icons.child_care_rounded, 'HBYC + Vaccination'),
    _RegisterOption('household', 'Household Survey', Icons.home_work_rounded, 'Gaon Swasthya Nondvahi'),
    _RegisterOption('ncd', 'BP / Sugar', Icons.favorite_rounded, 'NCD Tracking Register'),
    _RegisterOption('monthly', 'Monthly Report', Icons.bar_chart_rounded, 'ANM ko dena hota hai'),
  ];

  String _selectedGender = 'F';
  String _selectedRegister = 'patient';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _villageCtrl.dispose();
    _registerScrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _ageCtrl.text.trim().isEmpty ||
        _villageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ashaId = Supabase.instance.client.auth.currentUser?.id;
      if (ashaId == null || ashaId.isEmpty) {
        throw StateError('No signed-in Supabase user');
      }

      final patient = Patient(
        id: '',
        name: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text) ?? 0,
        village: _villageCtrl.text.trim(),
        registerType: _selectedRegister,
        ashaId: ashaId,
        lastMessage: 'Task record added',
        lastMessageTime: DateTime.now(),
      );

      final patientId = await FirebaseService.createPatient(patient);
      final visitId = await FirebaseService.createVisit(patientId, ashaId);
      await FirebaseService.logActivity(
        ActivityType.patientCreated,
        'Added new patient: ${patient.name}',
        metadata: {'patientId': patientId, 'visitId': visitId, 'registerType': _selectedRegister},
        patientId: patientId,
        visitId: visitId,
      );

      if (!mounted) return;
      context.pop();
      context.push('/chat/$patientId/$visitId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding patient: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: const Text('Add New Record'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Task Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 106,
                child: ListView.separated(
                  controller: _registerScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _registerOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final option = _registerOptions[index];
                    final selected = option.key == _selectedRegister;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRegister = option.key),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF075E54).withValues(alpha: 0.12) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? const Color(0xFF075E54) : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(option.icon, color: selected ? const Color(0xFF075E54) : Colors.grey.shade600),
                                const Spacer(),
                                if (selected)
                                  const Icon(Icons.check_circle, color: Color(0xFF075E54), size: 18),
                              ],
                            ),
                            const Spacer(),
                            Text(option.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(option.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Patient / Task Name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'F', child: Text('Female')),
                        DropdownMenuItem(value: 'M', child: Text('Male')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => _selectedGender = value ?? 'F'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _villageCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Village / Area *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF075E54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_isSubmitting ? 'Saving...' : 'Save Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterOption {
  final String key;
  final String label;
  final IconData icon;
  final String subtitle;

  const _RegisterOption(this.key, this.label, this.icon, this.subtitle);
}
