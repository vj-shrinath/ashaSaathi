import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/backend_api_service.dart';
import '../../core/models/gramnidan_register.dart';
import '../widgets/gramnidan_module_card.dart';
import '../widgets/idsp_disease_widget.dart';
import 'gramnidan_module_definitions.dart';
import '../../core/services/pdf_generation_service.dart';
import 'package:path_provider/path_provider.dart';

class AshaRegisterScreen extends StatefulWidget {
  const AshaRegisterScreen({super.key});

  @override
  State<AshaRegisterScreen> createState() => _AshaRegisterScreenState();
}

class _AshaRegisterScreenState extends State<AshaRegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  String? _selectedRegisterType;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _showResults = false;
  String _processingStep = '';
  String _liveTranscript = '';

  /// After AI fills, this holds: { moduleId: { fieldId: value } }
  Map<String, Map<String, String>> _filledModules = {};
  bool _hasWarnings = false;
  String? _savedRegisterId;

  final AudioRecorder _recorder = AudioRecorder();
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _voiceInputKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Register tile definitions ─────────────────────────────────────────────

  static const _registerTiles = [
    _RegisterTile('anc',        Icons.pregnant_woman, 'Pregnancy',      'ANC Tracking',       Color(0xFFC2185B)),
    _RegisterTile('hbnc',       Icons.child_friendly, 'Newborn',         'HBNC (0-28 days)',     Color(0xFF1A4731)),
    _RegisterTile('hbyc',       Icons.child_care, 'Child Health',    'HBYC (3-15 months)',           Color(0xFF2D6A4F)),
    _RegisterTile('child',      Icons.vaccines, 'Vaccination',     'HBYC + UIP Register',         Color(0xFF00838F)),
    _RegisterTile('village',    Icons.holiday_village, 'Household',       'Village Auth',      Color(0xFF023E8A)),
    _RegisterTile('ncd',        Icons.favorite, 'BP / Sugar',      'NCD Tracking',       Color(0xFF7B1E1E)),
    _RegisterTile('ec',         Icons.family_restroom, 'Eligible Couple', 'Family Planning',    Color(0xFF7B2D8E)),
    _RegisterTile('delivery',   Icons.local_hospital, 'Delivery/PNC',  'Prasav PNC',    Color(0xFFAD1457)),
    _RegisterTile('idsp',       Icons.biotech, 'Disease Surv.',   'IDSP Sanchar Rog',   Color(0xFF6A4C93)),
    _RegisterTile('birthdeath', Icons.assignment, 'Birth & Death',   'Janm Mrityu Info',        Color(0xFF4A4A4A)),
    _RegisterTile('claim',      Icons.attach_money, 'JSY Claim',  'Govt Scheme Claim',       Color(0xFFB8860B)),
    _RegisterTile('cbac',       Icons.assignment_ind, 'CBAC (30+)',      'NCD Screening',      Color(0xFFBB3E03)),
  ];

  // ── Voice Recording ──────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }
    
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _liveTranscript = '';
    });
  }

  Future<void> _stopAndProcess() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null || _selectedRegisterType == null) return;
    await _processVoiceNote(path);
  }

  Future<void> _processVoiceNote(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _showResults = false;
      _filledModules = {};
      _processingStep = 'Uploading audio...';
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // ── 1. Upload audio to Supabase Storage ─────────────────────────────
      setState(() => _processingStep = 'Processing audio in cloud...');
      final file = await _uploadAudioToStorage(audioPath, user.id);

      // ── 2. Call GramNidan Backend ────────────────────────────────────────
      setState(() => _processingStep = 'Extracting fields via AI...');
      final filledModules = await BackendApiService.fillGramNidanRegisters(
        audioUrl: file,
        registerType: _selectedRegisterType!,
        ashaId: user.id,
        ashaName: user.userMetadata?['full_name'] ?? 'ASHA Worker',
      );

      // ── 3. Save to Supabase ──────────────────────────────────────────────
      setState(() => _processingStep = 'Saving data...');
      final hasWarnings = filledModules.values.any(
        (fields) => fields.values.any((v) => v.contains('⚠️')),
      );
      final register = GramNidanRegister(
        id: '',
        ashaId: user.id,
        patientName: 'Voice Entry',
        registerType: _selectedRegisterType!,
        moduleData: filledModules,
        isWarning: hasWarnings,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final registerId = await FirebaseService.saveGramNidanRegister(register);

      setState(() {
        _isProcessing = false;
        _showResults = true;
        _filledModules = filledModules;
        _hasWarnings = hasWarnings;
        _savedRegisterId = registerId;
      });

      // Scroll to results
      await Future.delayed(const Duration(milliseconds: 200));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStep = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<String> _uploadAudioToStorage(String localPath, String userId) async {
    return FirebaseService.uploadAudio(
      File(localPath),
      '${userId}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // ── Submit to THO ─────────────────────────────────────────────────────────

  Future<void> _submitToTho() async {
    if (_savedRegisterId == null) return;
    
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final register = GramNidanRegister(
        id: _savedRegisterId!,
        ashaId: user?.id ?? '',
        patientName: 'Voice Entry',
        registerType: _selectedRegisterType!,
        moduleData: _filledModules,
        isWarning: _hasWarnings,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate and upload PDF
      final pdfBytes = await PdfGenerationService.generateRegisterPdf(register);
      final pdfUrl = await FirebaseService.uploadRegisterPdf(pdfBytes, _savedRegisterId!);
      
      // Submit to THO
      await FirebaseService.submitGramNidanToTho(_savedRegisterId!, pdfUrl: pdfUrl);
      
      if (mounted) {
        Navigator.pop(context); // hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Successfully submitted to THO!'),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Register'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── How it works banner ──────────────────────────────────────
            _HowItWorksBanner(),
            const SizedBox(height: 24),

            // ── Register Selector ────────────────────────────────────────
            Text(
              'Select Register Type',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _RegisterGrid(
              tiles: _registerTiles,
              selected: _selectedRegisterType,
              onSelect: (type) {
                setState(() {
                  _selectedRegisterType = type;
                  _showResults = false;
                  _filledModules = {};
                });
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_voiceInputKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _voiceInputKey.currentContext!,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      alignment: 0.1, // Align near the top of viewport
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            // ── Voice input area — visible when register selected ─────────
            if (_selectedRegisterType != null) ...[
              _VoiceInputCard(
                key: _voiceInputKey,
                registerType: _selectedRegisterType!,
                isRecording: _isRecording,
                liveTranscript: _liveTranscript,
                pulseController: _pulseController,
                onStart: _startRecording,
                onStop: _stopAndProcess,
              ),
              const SizedBox(height: 16),
            ],

            // ── Processing indicator ─────────────────────────────────────
            if (_isProcessing)
              _ProcessingCard(step: _processingStep),

            // ── GramNidan AI Results ─────────────────────────────────────
            if (_showResults && _filledModules.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ResultsHeader(
                hasWarnings: _hasWarnings,
                filledCount: _filledModules.length,
              ),
              const SizedBox(height: 12),
              // Render one accordion card per filled module
              ...GramNidanModuleDefinitions.modules
                  .where((m) => _filledModules.containsKey(m.id))
                  .map((module) => GramNidanModuleCard(
                        module: module,
                        filledFields: _filledModules[module.id] ?? {},
                        startExpanded: true,
                        onFieldEdited: (fieldId, newValue) {
                          setState(() {
                            _filledModules[module.id]![fieldId] = newValue;
                          });
                        },
                      )),
              // Show idsp widget specifically for idsp module
              if (_selectedRegisterType == 'idsp' &&
                  !_filledModules.containsKey('idsp'))
                IdspDiseaseWidget(
                  onDataChanged: (idspData) {
                    setState(() {
                      _filledModules['idsp'] = idspData;
                    });
                  },
                ),
              const SizedBox(height: 24),
              _SubmitBar(
                onSubmitToTho: _submitToTho,
                registerId: _savedRegisterId,
              ),
            ],

            // ── If idsp selected but processing not started — show widget ─
            if (_selectedRegisterType == 'idsp' &&
                !_isProcessing &&
                !_showResults) ...[
              const SizedBox(height: 12),
              IdspDiseaseWidget(
                onDataChanged: (idspData) {
                  setState(() {
                    _filledModules['idsp'] = idspData;
                    _showResults = true;
                    _hasWarnings = idspData.values.any((v) => v.contains('⚠️'));
                  });
                },
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              radius: 24,
              child: Icon(Icons.mic, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI-Powered Registers',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a register and record your voice note. The AI will automatically extract and structure the information into the required format.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Register tile model ───────────────────────────────────────────────────────
class _RegisterTile {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  const _RegisterTile(this.id, this.icon, this.title, this.subtitle, this.accent);
}

class _RegisterGrid extends StatelessWidget {
  final List<_RegisterTile> tiles;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _RegisterGrid({required this.tiles, this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) {
        final tile = tiles[i];
        final isSelected = tile.id == selected;
        return Card(
          elevation: isSelected ? 2 : 0,
          color: isSelected ? tile.accent.withValues(alpha: 0.1) : theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? tile.accent : theme.dividerColor.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelect(tile.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? tile.accent.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tile.icon,
                      color: isSelected ? tile.accent : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tile.title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? tile.accent : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tile.subtitle,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoiceInputCard extends StatelessWidget {
  final String registerType;
  final bool isRecording;
  final String liveTranscript;
  final AnimationController pulseController;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _VoiceInputCard({
    super.key,
    required this.registerType,
    required this.isRecording,
    required this.liveTranscript,
    required this.pulseController,
    required this.onStart,
    required this.onStop,
  });

  static const _hints = {
    'anc': 'Mention patient name, months pregnant, BP reading, and IFA details...',
    'hbnc': 'Mention newborn name, weight, umbilical cord state, breast feeding...',
    'village': 'Mention house number, head name, family size, sanitation details...',
    'ncd': 'Mention patient name, BP, sugar level, current medications, symptoms...',
    'cbac': 'Mention patient name, age, tobacco/alcohol habits, family history...',
    'idsp': 'Mention communicable disease if any (TB, Malaria) with patient name...',
    'child': 'Mention child name, weight, today\'s vaccines, any recent illness...',
    'delivery': 'Mention delivery date, location, baby weight, mother health...',
    'hbyc': 'Mention child name, age, weight, diet intake, current milestones...',
    'ec': 'Mention couple names, age, children count, family planning methods...',
    'birthdeath': 'Mention birth/death details, date, reason and family info...',
    'claim': 'Mention beneficiary name, delivery location and claim amount...',
  };

  @override
  Widget build(BuildContext context) {
    final hint = _hints[registerType] ?? 'Tap to record patient details directly into the register...';
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Voice Input',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (liveTranscript.isNotEmpty) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  '"$liveTranscript"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
            GestureDetector(
              onTap: isRecording ? onStop : onStart,
              child: AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) {
                  final color = isRecording 
                      ? Color.lerp(theme.colorScheme.error, theme.colorScheme.errorContainer, pulseController.value)
                      : theme.colorScheme.primary;
                  
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: isRecording
                          ? [BoxShadow(color: theme.colorScheme.error.withValues(alpha: 0.4 * pulseController.value), blurRadius: 20, spreadRadius: 4)]
                          : [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRecording ? 'Recording... tap to stop' : 'Tap to Record',
              style: theme.textTheme.labelLarge?.copyWith(
                color: isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  final String step;
  const _ProcessingCard({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                step,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final bool hasWarnings;
  final int filledCount;
  const _ResultsHeader({required this.hasWarnings, required this.filledCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Extracted Data',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Badge('$filledCount Modules Checked', theme.colorScheme.primary),
              if (hasWarnings) ...[
                const SizedBox(width: 8),
                _Badge('⚠️ Review Required', theme.colorScheme.error),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tap any extracted field to modify it manually before submitting.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color, 
          fontSize: 11, 
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final VoidCallback onSubmitToTho;
  final String? registerId;
  const _SubmitBar({required this.onSubmitToTho, this.registerId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: const Text('Saved Locally'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.send_rounded, size: 20),
            label: const Text('Submit to THO'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: registerId != null ? onSubmitToTho : null,
          ),
        ),
      ],
    );
  }
}
