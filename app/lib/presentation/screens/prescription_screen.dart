import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/patient_model.dart';
import '../../core/models/prescription.dart';
import '../../core/models/message_model.dart';
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
  TriageReport? _triageReport;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTriageExpanded = false;
  final List<Medication> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _followUpInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doctorId = FirebaseService.getCurrentUserId();
      debugPrint(
          'PrescriptionScreen: Loading patientId=${widget.patientId}, visitId=${widget.visitId}');
      final results = await Future.wait([
        FirebaseService.getPatientForDoctor(widget.patientId, doctorId),
        FirebaseService.getTriageReportByVisitId(widget.visitId),
      ]);
      if (mounted) {
        setState(() {
          _patient = results[0] as Patient?;
          _triageReport = results[1] as TriageReport?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patient data: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
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

  void _removeMedication(int index) {
    setState(() => _medications.removeAt(index));
  }

  void _showMedicationDialog({Medication? medication, int? index}) {
    final nameCtrl = TextEditingController(text: medication?.name ?? '');
    final dosageCtrl = TextEditingController(text: medication?.dosage ?? '');
    final frequencyCtrl = TextEditingController(text: medication?.frequency ?? '');
    final durationCtrl = TextEditingController(text: medication?.duration ?? '');
    final instructionsCtrl = TextEditingController(text: medication?.instructions ?? '');
    MedicationType selectedType = medication?.type ?? MedicationType.tablet;

    // Quick frequency options
    final quickFrequencies = [
      '1-0-1 (Twice daily)',
      '1-1-1 (Three times daily)',
      '1-0-0 (Once Morning)',
      '0-0-1 (Bedtime)',
      'As needed (SOS)',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF0F4C81)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    medication == null ? 'Add Medication' : 'Edit Medication',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Medication Type',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),

                  // Medication Type Chips Selector
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MedicationType.values.map((type) {
                      final isSelected = selectedType == type;
                      return ChoiceChip(
                        label: Text(type.displayName),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedType = type);
                        },
                        selectedColor: const Color(0xFF0F4C81),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        showCheckmark: false,
                        avatar: Icon(
                          _getMedIcon(type),
                          size: 14,
                          color: isSelected ? Colors.white : const Color(0xFF0F4C81),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Medicine Name
                  TextFormField(
                    controller: nameCtrl,
                    decoration: _inputDecoration(
                      label: 'Medicine Name *',
                      hint: 'e.g., Paracetamol, Amoxicillin',
                      icon: Icons.vaccines_rounded,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Dosage & Duration Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: dosageCtrl,
                          decoration: _inputDecoration(
                            label: 'Dosage *',
                            hint: 'e.g., 500 mg, 5 ml',
                            icon: Icons.straighten_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: durationCtrl,
                          decoration: _inputDecoration(
                            label: 'Duration *',
                            hint: 'e.g., 5 Days, 1 Week',
                            icon: Icons.timer_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Frequency
                  TextFormField(
                    controller: frequencyCtrl,
                    decoration: _inputDecoration(
                      label: 'Frequency *',
                      hint: 'e.g., 1-0-1 (Twice daily)',
                      icon: Icons.repeat_rounded,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Quick Frequency Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: quickFrequencies.map((freq) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() => frequencyCtrl.text = freq);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Text(
                                freq,
                                style: const TextStyle(color: Color(0xFF0369A1), fontSize: 11),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Instructions
                  TextFormField(
                    controller: instructionsCtrl,
                    maxLines: 2,
                    decoration: _inputDecoration(
                      label: 'Food / Special Directions',
                      hint: 'e.g., Take after food with warm water',
                      icon: Icons.info_outline_rounded,
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty ||
                      dosageCtrl.text.trim().isEmpty ||
                      frequencyCtrl.text.trim().isEmpty ||
                      durationCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields (*)'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                    return;
                  }

                  final newMed = Medication(
                    id: medication?.id ?? const Uuid().v4(),
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
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(medication == null ? 'Add Medication' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F4C81),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
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
        const SnackBar(
          content: Text('Please add at least one medication before saving'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final doctorId = FirebaseService.getCurrentUserId();
      final doctorName = FirebaseService.getCurrentUserName();
      final pId = const Uuid().v4();

      final prescription = Prescription(
        id: pId,
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

      final savedId = await FirebaseService.createPrescription(prescription);
      final finalPrescription = prescription.copyWith(id: savedId);

      await _sendPrescriptionMessage(finalPrescription);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription issued & sent to ASHA Chat successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.go('/chat/${widget.patientId}/${widget.visitId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving prescription: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPrescriptionMessage(Prescription prescription) async {
    try {
      final doctorId = FirebaseService.getCurrentUserId();
      final doctorName = FirebaseService.getCurrentUserName();

      final message = ChatMessage(
        id: const Uuid().v4(),
        type: MessageType.prescription,
        patientId: widget.patientId,
        visitId: widget.visitId,
        prescription: prescription,
        senderId: doctorId,
        senderName: doctorName,
        timestamp: DateTime.now(),
      );

      await FirebaseService.saveMessage(
        widget.visitId,
        message,
        patientId: widget.patientId,
      );
    } catch (e) {
      debugPrint('Error sending prescription message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF0F4C81)),
              SizedBox(height: 16),
              Text('Loading patient & medical history...',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (_patient == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Prescription Studio'),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text('Patient record not found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
                Color(0xFF0F4C81),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.note_add_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'E-Prescription Studio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Patient: ${_patient!.name}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Header Banner
                    _buildPatientBanner(),

                    const SizedBox(height: 16),

                    // ASHA Triage Context (Expandable)
                    if (_triageReport != null) _buildTriageSummaryCard(),
                    if (_triageReport != null) const SizedBox(height: 16),

                    // Diagnosis Card
                    _buildSectionContainer(
                      title: 'Clinical Diagnosis *',
                      icon: Icons.healing_rounded,
                      iconColor: const Color(0xFF0EA5E9),
                      child: TextFormField(
                        controller: _diagnosisController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                        decoration: _inputDecoration(
                          label: 'Primary Diagnosis / Clinical Impressions',
                          hint: 'e.g., Upper Respiratory Tract Infection with Fever',
                          icon: Icons.medical_information_rounded,
                        ),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'Diagnosis is required' : null,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Medications Card
                    _buildMedicationsSection(),

                    const SizedBox(height: 16),

                    // Instructions & Notes Card
                    _buildSectionContainer(
                      title: 'Directions & Follow-up',
                      icon: Icons.assignment_turned_in_rounded,
                      iconColor: const Color(0xFF10B981),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: _inputDecoration(
                              label: 'Additional Clinical Notes',
                              hint: 'Dietary advice, rest guidelines, or warnings',
                              icon: Icons.description_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _followUpInstructionsController,
                            maxLines: 2,
                            decoration: _inputDecoration(
                              label: 'Follow-up Instructions for ASHA Worker',
                              hint: 'e.g., Monitor temperature every 6 hrs; report if > 101°F',
                              icon: Icons.rule_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Date Selector
                          InkWell(
                            onTap: _selectFollowUpDate,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.event_rounded,
                                        color: Color(0xFF0F4C81), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Follow-up Review Date',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _followUpDate == null
                                              ? 'Tap to schedule follow-up date (optional)'
                                              : '${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year}',
                                          style: TextStyle(
                                            color: _followUpDate == null
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF0F172A),
                                            fontWeight: _followUpDate == null
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_followUpDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: Color(0xFF94A3B8)),
                                      onPressed: () => setState(() => _followUpDate = null),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom Save Action Bar
            _buildBottomSaveBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientBanner() {
    final riskColor = _getRiskColor(_patient?.riskCategory ?? 'Green');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor.withValues(alpha: 0.2), riskColor.withValues(alpha: 0.05)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: riskColor, width: 2),
            ),
            child: Center(
              child: Text(
                _patient!.name.isNotEmpty ? _patient!.name[0].toUpperCase() : 'P',
                style: TextStyle(
                  color: riskColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Patient details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _patient!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: riskColor),
                          const SizedBox(width: 4),
                          Text(
                            '${_patient!.riskCategory} Risk',
                            style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.cake_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${_patient!.age} yrs',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _patient!.village.isNotEmpty ? _patient!.village : 'Primary Village',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriageSummaryCard() {
    final report = _triageReport!;
    final riskColor = _getRiskColor(report.triageResult.riskCategory);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _isTriageExpanded,
            onExpansionChanged: (exp) => setState(() => _isTriageExpanded = exp),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded, color: Color(0xFF0F4C81), size: 20),
            ),
            title: const Text(
              'ASHA Triage Assessment Context',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              'Report by ASHA ${report.ashaName}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),

                    // Summary Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        report.triageResult.patientSummary,
                        style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.4),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Symptoms
                    if (report.triageResult.symptoms.isNotEmpty) ...[
                      const Text('Reported Symptoms:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: report.triageResult.symptoms.map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Suggested Action & Score
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Suggested Action:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              Text(
                                report.triageResult.suggestedAction,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Score: ${report.triageResult.riskScore}/10',
                            style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (report.transcript.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('ASHA Voice Recording Transcript:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '"${report.transcript}"',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationsSection() {
    return _buildSectionContainer(
      title: 'Prescribed Medications *',
      icon: Icons.medication_liquid_rounded,
      iconColor: const Color(0xFF0F4C81),
      headerAction: FilledButton.icon(
        onPressed: _addMedication,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Add Drug', style: TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0F4C81),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_medications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medication_outlined, size: 36, color: Color(0xFF0F4C81)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No medications added yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "Add Drug" above to specify tablets, syrups, or injections.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add First Medication'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F4C81),
                      side: const BorderSide(color: Color(0xFF0F4C81)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _medications.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final med = _medications[i];
                return _MedicationItemCard(
                  medication: med,
                  onEdit: () => _editMedication(i, med),
                  onDelete: () => _removeMedication(i),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? headerAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              ?headerAction,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isSaving ? null : _savePrescription,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C81),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isSaving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Issuing E-Prescription...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Issue & Send Prescription to ASHA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF0F4C81), size: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      fillColor: const Color(0xFFF8FAFC),
      filled: true,
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'Red':
        return const Color(0xFFEF4444);
      case 'Orange':
        return const Color(0xFFF97316);
      case 'Yellow':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF10B981);
    }
  }

  IconData _getMedIcon(MedicationType type) {
    switch (type) {
      case MedicationType.tablet:
        return Icons.medication_rounded;
      case MedicationType.capsule:
        return Icons.medication_liquid_rounded;
      case MedicationType.syrup:
        return Icons.local_drink_rounded;
      case MedicationType.injection:
        return Icons.vaccines_rounded;
      case MedicationType.drops:
        return Icons.water_drop_rounded;
      case MedicationType.ointment:
        return Icons.healing_rounded;
      case MedicationType.inhaler:
        return Icons.air_rounded;
      default:
        return Icons.medication_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDICATION ITEM CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MedicationItemCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicationItemCard({
    required this.medication,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(medication.type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getMedIcon(medication.type), color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      medication.type.displayName,
                      style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF0F4C81)),
                    onPressed: onEdit,
                    tooltip: 'Edit Drug',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    onPressed: onDelete,
                    tooltip: 'Remove Drug',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Pills for Dosage, Frequency, Duration
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _infoPill(label: medication.dosage, icon: Icons.straighten_rounded, color: const Color(0xFF0EA5E9)),
              _infoPill(label: medication.frequency, icon: Icons.repeat_rounded, color: const Color(0xFF8B5CF6)),
              _infoPill(label: medication.duration, icon: Icons.timer_rounded, color: const Color(0xFF10B981)),
            ],
          ),

          if (medication.instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      medication.instructions,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoPill({required String label, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(MedicationType type) {
    switch (type) {
      case MedicationType.tablet:
        return const Color(0xFF0F4C81);
      case MedicationType.capsule:
        return const Color(0xFF8B5CF6);
      case MedicationType.syrup:
        return const Color(0xFFD97706);
      case MedicationType.injection:
        return const Color(0xFFEF4444);
      case MedicationType.drops:
        return const Color(0xFF0EA5E9);
      case MedicationType.ointment:
        return const Color(0xFF10B981);
      case MedicationType.inhaler:
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getMedIcon(MedicationType type) {
    switch (type) {
      case MedicationType.tablet:
        return Icons.medication_rounded;
      case MedicationType.capsule:
        return Icons.medication_liquid_rounded;
      case MedicationType.syrup:
        return Icons.local_drink_rounded;
      case MedicationType.injection:
        return Icons.vaccines_rounded;
      case MedicationType.drops:
        return Icons.water_drop_rounded;
      case MedicationType.ointment:
        return Icons.healing_rounded;
      case MedicationType.inhaler:
        return Icons.air_rounded;
      default:
        return Icons.medication_rounded;
    }
  }
}