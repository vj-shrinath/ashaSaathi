import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// WhatsApp-style voice recorder bottom bar.
/// Shows: text input + mic button.
/// Hold mic → record → release → triggers [onAudioReady].
class VoiceRecorderBar extends StatefulWidget {
  final Function(File audioFile) onAudioReady;
  final Function(String text) onTextSend;
  final VoidCallback? onCancelRecording;
  final bool isProcessing;

  const VoiceRecorderBar({
    super.key,
    required this.onAudioReady,
    required this.onTextSend,
    this.onCancelRecording,
    this.isProcessing = false,
  });

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isCancelled = false;
  bool _hasText = false;
  int _recordSeconds = 0;
  Timer? _timer;
  String? _recordingPath;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.3).animate(_pulseController);
    _textController.addListener(() {
      setState(() => _hasText = _textController.text.trim().isNotEmpty);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isRecording) {
      _recorder.stop();
    }
    _recorder.dispose();
    _timer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    if (!mounted) return;

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: _recordingPath!,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _isCancelled = false;
          _recordSeconds = 0;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordSeconds++);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_isRecording) {
      if (cancel) {
        setState(() {
          _isCancelled = true;
        });
      }
      return;
    }

    _timer?.cancel();

    try {
      final path = await _recorder.stop();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isCancelled = false;
        });

        if (!cancel && path != null) {
          try {
            widget.onAudioReady(File(path));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error processing audio: ${e.toString()}')),
              );
            }
          }
        } else if (cancel) {
          widget.onCancelRecording?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isCancelled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5);

    return Container(
      color: barColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: _isRecording ? _buildRecordingUI(theme) : _buildNormalUI(theme),
      ),
    );
  }

  Widget _buildNormalUI(ThemeData theme) {
    return Row(
      children: [
        // Mic Button (left side) - permanently visible
        GestureDetector(
          onTap: widget.isProcessing || _hasText ? null : _startRecording,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.isProcessing || _isRecording
                  ? Colors.grey.withValues(alpha: 0.5)
                  : theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.isProcessing || _isRecording
                      ? Colors.grey.withValues(alpha: 0.3)
                      : theme.colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: widget.isProcessing || _isRecording ? 0 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),

        // Text Field (main area) - center aligned
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF2A3942)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !widget.isProcessing && !_isRecording,
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Recording...' : 'Type a message...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                if (_hasText && !widget.isProcessing && !_isRecording)
                  IconButton(
                    onPressed: () {
                      widget.onTextSend(_textController.text.trim());
                      _textController.clear();
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingUI(ThemeData theme) {
    return Row(
      children: [
        // Cancel hint
        const Icon(Icons.keyboard_arrow_left, color: Colors.grey, size: 18),
        Expanded(
          child: Center(
            child: Text(
              _isCancelled
                  ? '< Release to cancel'
                  : '🎙️  ${_formatDuration(_recordSeconds)}  Recording...',
              style: TextStyle(
                color: _isCancelled ? Colors.red : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Pulsing mic
        ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: () => _stopRecording(cancel: _isCancelled),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _isCancelled ? Colors.grey : Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        ),
      ],
    );
  }
}
