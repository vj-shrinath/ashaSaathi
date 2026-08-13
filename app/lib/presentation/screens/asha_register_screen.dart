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
import 'package:printing/printing.dart';

class AshaRegisterScreen extends StatefulWidget {
  final String? initialRegisterType;

  const AshaRegisterScreen({super.key, this.initialRegisterType});

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
  int _recordDurationSeconds = 0;
  Timer? _timer;

  /// After AI fills, this holds: { moduleId: { fieldId: value } }
  Map<String, Map<String, String>> _filledModules = {};
  bool _hasWarnings = false;
  String? _savedRegisterId;

  final AudioRecorder _recorder = AudioRecorder();
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _voiceInputKey = GlobalKey();

  final Map<String, GlobalKey> _moduleKeys = {};

  @override
  void initState() {
    super.initState();
    _selectedRegisterType = widget.initialRegisterType;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    for (final m in GramNidanModuleDefinitions.modules) {
      _moduleKeys[m.id] = GlobalKey();
    }

    if (_selectedRegisterType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_voiceInputKey.currentContext != null) {
          Scrollable.ensureVisible(
            _voiceInputKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    }
  }

  List<String> _getModuleIdsForRegisterType(String? type) {
    switch (type) {
      case 'pregnancy':
        return ['anc', 'delivery'];
      case 'newborn':
        return ['hbnc'];
      case 'child':
        return ['hbyc', 'child'];
      case 'household':
        return ['village'];
      case 'bpsugar':
        return ['ncd'];
      case 'cbac':
        return ['cbac'];
      case 'idsp':
        return ['idsp'];
      case 'monthly':
        return ['inventory'];
      default:
        return [];
    }
  }

  void _scrollToModuleCard(String? registerType) {
    final related = _getModuleIdsForRegisterType(registerType);
    final targetId = related.isNotEmpty ? related.first : null;
    if (targetId != null && _moduleKeys[targetId]?.currentContext != null) {
      Scrollable.ensureVisible(
        _moduleKeys[targetId]!.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    } else if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _recordDurationSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDurationSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    _recorder.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Register tile definitions ─────────────────────────────────────────────

  static const _registerTiles = [
    _RegisterTile('pregnancy', '🤰', 'Pregnancy', 'ANC Tracking Register', Color(0xFF1A4731)),
    _RegisterTile('newborn', '👶', 'Newborn', 'HBNC Register (0-28 din)', Color(0xFFF4A261)),
    _RegisterTile('child', '🧒', 'Child Health', 'HBYC + Vaccination', Color(0xFFE9C46A)),
    _RegisterTile('household', '🏘️', 'Household Survey', 'Gaon Swasthya Nondvahi', Color(0xFFE76F51)),
    _RegisterTile('bpsugar', '❤️', 'BP / Sugar', 'NCD Tracking Register', Color(0xFFD62828)),
    _RegisterTile('cbac', '🩺', 'CBAC Register', 'Community Assessment Checklist', Color(0xFF023E8A)),
    _RegisterTile('idsp', '🦟', 'Disease Tracker', 'IDSP Disease Surveillance', Color(0xFF6A4C93)),
    _RegisterTile('monthly', '📊', 'Monthly Report', 'ANM & PHC Submissions', Color(0xFF2D6A4F)),
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
    _startTimer();
  }

  Future<void> _stopAndProcess() async {
    if (!_isRecording) return;
    _stopTimer();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null || _selectedRegisterType == null) return;
    await _processVoiceNote(path);
  }

  String _selectedLanguage = 'hi'; // Hindi ('hi'), Marathi ('mr'), English ('en')

  Future<void> _processVoiceNote(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _showResults = false;
      _filledModules = {};
      _processingStep = 'Uploading audio stream...';
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // ── 1. Upload audio to Supabase Storage ─────────────────────────────
      setState(() => _processingStep = 'Processing audio in cloud AI model...');
      final file = await _uploadAudioToStorage(audioPath, user.id);

      // ── 2. Call GramNidan Backend (AI extraction & DB save) ─────────────
      setState(() => _processingStep = 'Extracting GramNidan fields & structuring...');
      final result = await BackendApiService.fillGramNidanRegisters(
        audioUrl: file,
        registerType: _selectedRegisterType!,
        ashaId: user.id,
        ashaName: user.userMetadata?['full_name'] ?? 'ASHA Worker',
        language: _selectedLanguage,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _showResults = true;
        _filledModules = result.filledModules;
        _hasWarnings = result.hasWarnings;
        _savedRegisterId = result.registerId;
      });

      // Auto-scroll directly to related module card
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToModuleCard(_selectedRegisterType);
      });
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

  // ── Save PDF / Submit to MO ───────────────────────────────────────────────

  Future<void> _savePdfToLocal() async {
    if (_savedRegisterId == null) return;
    
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

      final pdfBytes = await PdfGenerationService.generateRegisterPdf(register);
      
      if (mounted) {
        Navigator.pop(context);
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'GramNidan_Register_${_selectedRegisterType}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save PDF failed: $e')),
        );
      }
    }
  }

  Future<void> _submitToMo() async {
    if (_savedRegisterId == null) return;
    
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
      
      // Submit to MO
      await FirebaseService.submitGramNidanToTho(
        _savedRegisterId!, 
        pdfUrl: pdfUrl,
        moduleData: _filledModules,
      );
      
      if (mounted) {
        Navigator.pop(context); // hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Successfully sent to Medical Officer (MO)!'),
            backgroundColor: Color(0xFF2D6A4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GramNidan Voice Registers',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── How it works banner ──────────────────────────────────────
            _HowItWorksBanner(),
            const SizedBox(height: 20),

            // ── Register Selector Title ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Register Type',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1B4332),
                    letterSpacing: 0.2,
                  ),
                ),
                if (_selectedRegisterType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Color(0xFF2D6A4F),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _RegisterGrid(
              tiles: _registerTiles,
              selected: _selectedRegisterType,
              onSelect: (type) {
                setState(() {
                  _selectedRegisterType = type;
                });
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_showResults) {
                    _scrollToModuleCard(type);
                  } else if (_voiceInputKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _voiceInputKey.currentContext!,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      alignment: 0.1,
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
                selectedLanguage: _selectedLanguage,
                onLanguageChanged: (lang) => setState(() => _selectedLanguage = lang),
                isRecording: _isRecording,
                recordDurationSeconds: _recordDurationSeconds,
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
            if (_showResults) ...[
              const SizedBox(height: 16),
              if (_filledModules.isEmpty)
                Card(
                  elevation: 0,
                  color: Colors.orange.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AI could not extract structured data from this recording. Try recording again with clearer patient details.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _ResultsHeader(
                  hasWarnings: _hasWarnings,
                  filledCount: _filledModules.length,
                ),
                const SizedBox(height: 12),

                // ── Continuous stream of all register modules ──
                ...GramNidanModuleDefinitions.modules.map((module) {
                  final filled = _filledModules[module.id];
                  final isFilled = filled != null && filled.isNotEmpty;
                  final related = _getModuleIdsForRegisterType(_selectedRegisterType);
                  final isRelated = related.contains(module.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GramNidanModuleCard(
                      key: _moduleKeys[module.id],
                      module: module,
                      filledFields: filled ?? {},
                      startExpanded: isFilled || isRelated,
                      onFieldEdited: (fieldId, newValue) {
                        setState(() {
                          _filledModules[module.id] ??= {};
                          _filledModules[module.id]![fieldId] = newValue;
                        });
                      },
                    ),
                  );
                }),

                const SizedBox(height: 24),
                _SubmitBar(
                  onSubmitToMo: _submitToMo,
                  onSaveLocal: _savePdfToLocal,
                  registerId: _savedRegisterId,
                ),
              ],
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1B4332), const Color(0xFF0F2E20)]
              : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2D6A4F).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF2D6A4F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Voice Register Assistant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B4332),
                      ),
                    ),
                    Text(
                      'Speak naturally in Hindi, Marathi, or English',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF2D6A4F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3-step workflow pills
          Row(
            children: [
              _buildStepPill(context, step: '1', label: 'Select Register'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
              ),
              _buildStepPill(context, step: '2', label: 'Record Voice'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
              ),
              _buildStepPill(context, step: '3', label: 'Auto-Fill & Save'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill(BuildContext context, {required String step, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 9,
              backgroundColor: const Color(0xFF2D6A4F),
              child: Text(
                step,
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  const _RegisterTile(this.id, this.emoji, this.title, this.subtitle, this.accent);
}

class _RegisterGrid extends StatelessWidget {
  final List<_RegisterTile> tiles;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _RegisterGrid({required this.tiles, this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? tile.accent.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? const Color(0xFF1E2C35) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? tile.accent
                  : (isDark ? Colors.white12 : Colors.grey.shade200),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: tile.accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelect(tile.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tile.accent.withValues(alpha: 0.25)
                            : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        tile.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tile.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected
                                        ? tile.accent
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: tile.accent,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tile.subtitle,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              fontSize: 9.5,
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
          ),
        );
      },
    );
  }
}

class _VoiceInputCard extends StatelessWidget {
  final String registerType;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isRecording;
  final int recordDurationSeconds;
  final String liveTranscript;
  final AnimationController pulseController;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _VoiceInputCard({
    super.key,
    required this.registerType,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isRecording,
    required this.recordDurationSeconds,
    required this.liveTranscript,
    required this.pulseController,
    required this.onStart,
    required this.onStop,
  });

  static const _hints = {
    'pregnancy': 'Patient ka naam, umra, pati ka naam, gaon, mahine, BP, IFA le rahi hai ya nahi, ANC visit, koi takleef — yeh bolo:',
    'newborn': 'Bachche ka naam, vajan, maa ka naam, tapman, naaf ki stithi, doodh pi raha hai ya nahi — yeh bolo:',
    'child': 'Bachche ka naam, vajan, kaun sa tika laga, diet kaisa hai — yeh bolo:',
    'household': 'Ghar ka number, mukhya ka naam, kitne sadasya, mobile number — yeh bolo:',
    'bpsugar': 'Patient ka naam, umra, aaj ka BP ya sugar reading, dawa chal rahi hai — yeh bolo:',
    'cbac': 'Patient ka naam, umra, tambaku ya sharab ki aadat, kamar ka naap — yeh bolo:',
    'idsp': 'Mariyaz ka naam, bukhar, khansi ya koi anokha lakshan — yeh bolo:',
    'monthly': 'Is mahine ki poori detail, kitne new registration hue — yeh bolo:',
  };

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final hint = _hints[registerType] ?? 'Tap to record patient details directly into the register...';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2C35) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRecording
              ? Colors.red.shade400
              : const Color(0xFF2D6A4F).withValues(alpha: 0.3),
          width: isRecording ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isRecording
                ? Colors.red.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_none_rounded, color: Color(0xFF2D6A4F), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Voice Note Input',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B4332),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hint box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF2D6A4F), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[800],
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Language Selector Choice Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '🌐 Bhasha: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('🇮🇳 हिंदी', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: selectedLanguage == 'hi',
                    selectedColor: const Color(0xFF2D6A4F).withValues(alpha: 0.2),
                    onSelected: (val) {
                      if (val) onLanguageChanged('hi');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('🚩 मराठी', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: selectedLanguage == 'mr',
                    selectedColor: Colors.orange.shade100,
                    onSelected: (val) {
                      if (val) onLanguageChanged('mr');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('🇬🇧 English', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    selected: selectedLanguage == 'en',
                    selectedColor: Colors.blue.shade100,
                    onSelected: (val) {
                      if (val) onLanguageChanged('en');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recording Timer Badge
            if (isRecording) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recording... ${_formatDuration(recordDurationSeconds)}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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

            // Animated Mic Button with Ripple Ring Effect
            GestureDetector(
              onTap: isRecording ? onStop : onStart,
              child: AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isRecording) ...[
                        Container(
                          width: 108 + (pulseController.value * 20),
                          height: 108 + (pulseController.value * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.15 * (1 - pulseController.value)),
                          ),
                        ),
                        Container(
                          width: 90 + (pulseController.value * 12),
                          height: 90 + (pulseController.value * 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.25 * (1 - pulseController.value)),
                          ),
                        ),
                      ],
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: isRecording
                              ? const LinearGradient(
                                  colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                                ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isRecording
                                  ? Colors.red.withValues(alpha: 0.4)
                                  : const Color(0xFF2D6A4F).withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 14),
            Text(
              isRecording ? 'Tap to Stop & Extract' : 'Tap to Record Voice Note',
              style: TextStyle(
                color: isRecording ? Colors.red[700] : const Color(0xFF2D6A4F),
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2C35) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  color: Color(0xFF2D6A4F),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1B4332),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              color: Color(0xFF2D6A4F),
              backgroundColor: Color(0x222D6A4F),
              minHeight: 4,
            ),
          ),
        ],
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E26) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF2D6A4F), size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Extracted GramNidan Data',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1B4332),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Badge('$filledCount Modules Checked', const Color(0xFF2D6A4F)),
              if (hasWarnings) ...[
                const SizedBox(width: 8),
                const _Badge('⚠️ Review Required', Colors.red),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap any extracted field to modify it manually before submitting.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[700],
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
  final VoidCallback onSubmitToMo;
  final VoidCallback onSaveLocal;
  final String? registerId;
  const _SubmitBar({required this.onSubmitToMo, required this.onSaveLocal, this.registerId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            '— OFFICIAL REGISTER ACTION CONTROLS —',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: const Text('Save PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D6A4F),
                  side: const BorderSide(color: Color(0xFF2D6A4F)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: registerId != null ? onSaveLocal : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('Send to MO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: registerId != null ? onSubmitToMo : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
