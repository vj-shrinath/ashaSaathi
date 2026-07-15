import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/message_model.dart';
import '../../core/models/patient_model.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/backend_api_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_recorder_bar.dart';

class ChatScreen extends StatefulWidget {
  final String patientId;
  final String visitId;

  const ChatScreen({
    super.key,
    required this.patientId,
    required this.visitId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _audioPlayer = AudioPlayer();
  final _uuid = const Uuid();
  String? get _ashaId => Supabase.instance.client.auth.currentUser?.id;

  Patient? _patient;
  String? _activeVisitId;
  bool _isProcessing = false;
  bool _isRecording = false;
  String? _playingAudioUrl;

  @override
  void initState() {
    super.initState();
    _loadPatient();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadPatient() async {
    final p = await FirebaseService.getPatient(widget.patientId);
    if (mounted) {
      setState(() {
        _patient = p;
        _activeVisitId = widget.visitId;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send Text Message ────────────────────────────────────────────────────────

  Future<void> _sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    final msg = ChatMessage(
      id: _uuid.v4(),
      type: MessageType.text,
      patientId: widget.patientId,
      visitId: widget.visitId,
      textContent: text,
      senderId: 'asha_worker',
      senderName: 'ASHA Worker',
      timestamp: DateTime.now(),
    );
    await FirebaseService.saveMessage(
      widget.visitId,
      msg,
      patientId: widget.patientId,
    );
    await FirebaseService.updatePatient(
      widget.patientId,
      lastMessage: text,
    );
    _scrollToBottom();
  }

  // ── Handle Voice Note ─────────────────────────────────────────────────────────

  Future<void> _handleVoiceNote(File audioFile) async {
    if (_isProcessing) return;

    final ashaId = _ashaId;
    if (ashaId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in again to send voice notes.')),
        );
      }
      return;
    }
    
    setState(() => _isProcessing = true);

    // 1. Save a "processing" placeholder bubble instantly
    final processingMsg = ChatMessage(
      id: _uuid.v4(),
      type: MessageType.voice,
      patientId: widget.patientId,
      visitId: widget.visitId,
      senderId: 'asha_worker',
      senderName: 'ASHA Worker',
      timestamp: DateTime.now(),
      isProcessing: true,
    );
    final processingMsgId =
        await FirebaseService.saveMessage(
      widget.visitId,
      processingMsg,
      patientId: widget.patientId,
    );
    _scrollToBottom();

    try {
      // 2. Upload audio to Firebase Storage
      final audioUrl =
          await FirebaseService.uploadAudio(audioFile, widget.visitId);

      // 3. Call backend: Sarvam STT + Claude Triage → saved to Firestore
      final triageResult = await BackendApiService.transcribeAndAnalyze(
        audioUrl: audioUrl,
        visitId: widget.visitId,
        patientId: widget.patientId,
        ashaId: ashaId,
        patientName: _patient?.name ?? 'Patient',
        ashaName: 'ASHA Worker',
      );

      // 4. Update the placeholder: show voice bubble with transcript
      await FirebaseService.updateMessage(
        widget.visitId,
        processingMsgId,
        {
          'is_processing': false,
          'audio_url': audioUrl,
          'transcript': triageResult.patientSummary,
        },
      );

      // 5. Add triage result bubble
      final triageMsg = ChatMessage(
        id: _uuid.v4(),
        type: MessageType.triageResult,
        patientId: widget.patientId,
        visitId: widget.visitId,
        triageResult: triageResult,
        transcript: triageResult.patientSummary,
        senderId: 'system',
        senderName: 'ASHA Saathi AI',
        timestamp: DateTime.now(),
      );
      await FirebaseService.saveMessage(
        widget.visitId,
        triageMsg,
        patientId: widget.patientId,
      );

      // 6. Update patient risk category
      await FirebaseService.updatePatient(
        widget.patientId,
        riskCategory: triageResult.riskCategory,
        lastMessage: '🎙️ Voice report - ${triageResult.riskCategory} risk',
      );

      _scrollToBottom();
    } catch (e) {
      final errorText = e.toString();
      await FirebaseService.updateMessage(
        widget.visitId,
        processingMsgId,
        {
          'is_processing': false,
          'text_content': '⚠️ Error processing voice note: $errorText',
          'type': MessageType.text.name,
        },
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleVoiceRecordingStateChange(bool isRecording) {
    if (!_isProcessing) {
      setState(() {
        _isRecording = isRecording;
        if (!isRecording) {
          _scrollToBottom();
        }
      });
    }
  }

  // ── Play Audio ────────────────────────────────────────────────────────────────

  Future<void> _playAudio(String? url) async {
    if (url == null) return;
    if (_playingAudioUrl == url) {
      await _audioPlayer.stop();
      setState(() => _playingAudioUrl = null);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _playingAudioUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFECE5DD),
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: FirebaseService.watchPatientMessages(widget.patientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return _buildEmptyState(theme);
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                  final visibleMessages = messages;

                  return ListView(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    children: [
                      ...visibleMessages.map((msg) {
                        final isMine = msg.senderId == 'asha_worker';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ChatBubble(
                            message: msg,
                            isSentByMe: isMine,
                            onPlayAudio: () => _playAudio(msg.audioUrl),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      _buildHistorySummary(theme, visibleMessages),
                    ],
                  );
                },
              ),
            ),

          // Bottom Input Bar
          VoiceRecorderBar(
            isProcessing: _isProcessing,
            onAudioReady: _handleVoiceNote,
            onTextSend: _sendTextMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySummary(ThemeData theme, List<ChatMessage> messages) {
    final totalMessages = messages.length;
    TriageResult? latestTriage;
    for (final msg in messages) {
      if (msg.triageResult != null) {
        latestTriage = msg.triageResult;
        break;
      }
    }
    final recentNotes = messages
        .where((m) => (m.transcript ?? m.textContent ?? '').trim().isNotEmpty)
        .take(3)
        .map((m) => m.transcript ?? m.textContent ?? '')
        .toList();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Patient History',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalMessages messages',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (latestTriage != null) ...[
              const SizedBox(height: 10),
              _buildHistoryPill(
                theme,
                'Latest risk: ${latestTriage.riskCategory}',
                _riskColorForCategory(latestTriage.riskCategory),
              ),
              const SizedBox(height: 8),
              Text(
                latestTriage.patientSummary,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (recentNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Recent notes',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...recentNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $note',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPill(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _riskColorForCategory(String category) {
    switch (category) {
      case 'Red':
        return Colors.red;
      case 'Orange':
        return Colors.orange;
      case 'Yellow':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF1F2C34)
          : const Color(0xFF075E54),
      foregroundColor: Colors.white,
      leadingWidth: 36,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _patient?.name ?? 'Asha',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  _patient != null
                      ? '${_patient!.age}y • ${_patient!.village} • ${_patient!.riskCategory} Risk'
                      : 'Opening chat...',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.video_call_rounded),
          onPressed: () {},
          tooltip: 'Video Call (coming soon)',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic_none_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a Visit',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Hold the 🎙️ mic button to record a voice note.\nSarvam AI will transcribe it and ASHA Saathi will generate a triage report.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
