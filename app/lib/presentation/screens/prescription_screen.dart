import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/patient_model.dart';
import '../../core/models/prescription.dart';
import '../../core/services/firebase_service.dart';

class PrescriptionScreen extends StatefulWidget {
  final String patientId;
  final String visitId;

  const PrescriptionScreen({
    super.key,
    required this.patientId,
    required this.visitId,
  });

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _followUpInstructionsController = TextEditingController();
  DateTime? _followUpDate;

  Patient? _patient;
  bool _isLoading = true;
  bool _isSaving = false;
  List<Medication> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _followUpInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadPatient() async {
    try {
      final patient = await FirebaseService.getPatient(widget.patientId);
      if (mounted) {
        setState(() {
          _patient = patient;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading patient: $e')),
        );
      }
    }
  }

  void _addMedication() {
    _showMedicationDialog();
  }

  void _editMedication(int index, Medication medication) {
    _showMedicationDialog(medication: medication, index: index);
  }

  void _showMedicationDialog({Medication? medication, int? index}) {
    final nameCtrl = TextEditingController(text: medication?.name ?? '');
    final dosageCtrl = TextEditingController(text: medication?.dosage ?? '');
    final frequencyCtrl = TextEditingController(text: medication?.frequency ?? '');
    final durationCtrl = TextEditingController(text: medication?.duration ?? '');
    final instructionsCtrl = TextEditingController(text: medication?.instructions ?? '');
    MedicationType selectedType = medication?.type ?? MedicationType.tablet;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(medication == null ? 'Add Medication' : 'Edit Medication'),
        content: SingleChildScrollView(
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name *',
                    hintText: 'e.g., Paracetamol',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dosageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dosage *',
                    hintText: 'e.g., 500mg',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: frequencyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Frequency *',
                    hintText: 'e.g., 3 times daily',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: durationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duration *',
                    hintText: 'e.g., 5 days',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MedicationType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: MedicationType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.displayName),
                  )).toList(),
                  onChanged: (v) => selectedType = v ?? MedicationType.tablet,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: instructionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    hintText: 'e.g., Take after meals',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty ||
                  dosageCtrl.text.trim().isEmpty ||
                  frequencyCtrl.text.trim().isEmpty ||
                  durationCtrl.text.trim().isEmpty) {
                return;
              }

              final newMed = Medication(
                id: medication?.id ?? '',
                name: nameCtrl.text.trim(),
                dosage: dosageCtrl.text.trim(),
                frequency: frequencyCtrl.text.trim(),
                duration: durationCtrl.text.trim(),
                instructions: instructionsCtrl.text.trim(),
                type: selectedType,
              );

              setState(() {
                if (index != null) {
                  _medications[index] = newMed;
                } else {
                  _medications.add(newMed);
                }
              });
              Navigator.pop(ctx);
            },
            child: Text(medication == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _removeMedication(int index) {
    setState(() => _medications.removeAt(index));
  }

  Future<void> _selectFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() => _followUpDate = date);
    }
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_patient == null) return;
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medication')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final doctorId = FirebaseService.getCurrentUserId();
      final doctorName = FirebaseService.getCurrentUserName();

      final prescription = Prescription(
        id: '',
        patientId: widget.patientId,
        visitId: widget.visitId,
        doctorId: doctorId,
        doctorName: doctorName,
        patientName: _patient!.name,
        createdAt: DateTime.now(),
        medications: _medications,
        diagnosis: _diagnosisController.text.trim(),
        notes: _notesController.text.trim(),
        followUpInstructions: _followUpInstructionsController.text.trim(),
        followUpDate: _followUpDate,
        status: PrescriptionStatus.active,
      );

      await FirebaseService.createPrescription(prescription);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription created successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating prescription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Prescription')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Prescription')),
        body: const Center(child: Text('Patient not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Prescription'),
        backgroundColor: const Color(0xFF0277BD),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Card
              Card(
                color: const Color(0xFF0277BD).withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF0277BD).withValues(alpha: 0.2),
                        child: Text(
                          _patient!.name.isNotEmpty
                              ? _patient!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Color(0xFF0277BD),
                              fontWeight: FontWeight.bold,
                              fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patient!.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_patient!.age} years • ${_patient!.village}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              'Risk: ${_patient!.riskCategory}',
                              style: TextStyle(
                                color: _getRiskColor(_patient!.riskCategory),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Diagnosis
              Text('Diagnosis *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  hintText: 'Enter diagnosis',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Medications
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Medications *', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF0277BD)),
                  ),
                ],
              ),

              if (_medications.isEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.medication_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No medications added',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _addMedication,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add First Medication'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0277BD)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                ..._medications.asMap().entries.map((entry) {
                  final index = entry.key;
                  final med = entry.value;
                  return _MedicationCard(
                    medication: med,
                    onEdit: () => _editMedication(index, med),
                    onDelete: () => _removeMedication(index),
                  );
                }),
              ],

              const SizedBox(height: 20),

              // Notes
              Text('Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  hintText: 'Any additional notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Follow-up Instructions
              Text('Follow-up Instructions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _followUpInstructionsController,
                decoration: const InputDecoration(
                  labelText: 'Follow-up Instructions',
                  hintText: 'e.g., Return in 3 days if no improvement',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // Follow-up Date
              Text('Follow-up Date', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectFollowUpDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Text(
                        _followUpDate == null
                            ? 'Select follow-up date (optional)'
                            : '${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year}',
                        style: TextStyle(
                          color: _followUpDate == null ? Colors.grey[500] : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _savePrescription,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save Prescription'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0277BD),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'Red':
        return Colors.red;
      case 'Orange':
        return Colors.orange;
      case 'Yellow':
        return Colors.amber[700]!;
      default:
        return Colors.green;
    }
  }
}

class _MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicationCard({
    required this.medication,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getMedIcon(medication.type), color: Colors.deepPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medication.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('${medication.dosage} • ${medication.frequency} • ${medication.duration}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (medication.instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(medication.instructions, style: TextStyle(color: Colors.grey[700])),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getMedIcon(MedicationType type) {
    switch (type) {
      case MedicationType.tablet:
        return Icons.medication;
      case MedicationType.capsule:
        return Icons.medication_outlined;
      case MedicationType.syrup:
        return Icons.local_drink;
      case MedicationType.injection:
        return Icons.vaccines;
      case MedicationType.drops:
        return Icons.opacity;
      case MedicationType.ointment:
        return Icons.healing;
      case MedicationType.inhaler:
        return Icons.air;
      default:
        return Icons.medication;
    }
  }
}