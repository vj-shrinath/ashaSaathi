import 'package:flutter/material.dart';
import '../../core/models/message_model.dart';
import 'triage_report_card.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;
  final VoidCallback? onPlayAudio;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSentByMe,
    this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isProcessing) {
      return _ProcessingBubble();
    }

    switch (message.type) {
      case MessageType.triageResult:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: TriageReportCard(
            report: message.triageResult!,
            transcript: message.transcript ?? '',
            compact: true,
          ),
        );
      case MessageType.doctorSuggestion:
        return _DoctorSuggestionBubble(
          message: message,
          isSentByMe: isSentByMe,
        );
      case MessageType.voice:
        return _VoiceBubble(
          message: message,
          isSentByMe: isSentByMe,
          onPlay: onPlayAudio,
        );
      default:
        return _TextBubble(
          message: message,
          isSentByMe: isSentByMe,
        );
    }
  }
}

// ── Text Bubble ────────────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;

  const _TextBubble({required this.message, required this.isSentByMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentColor = const Color(0xFF005C4B);
    final receivedColor = theme.brightness == Brightness.dark
        ? const Color(0xFF1F2C34)
        : Colors.white;

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isSentByMe ? 60 : 8,
          right: isSentByMe ? 8 : 60,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSentByMe ? sentColor : receivedColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isSentByMe ? 12 : 2),
            bottomRight: Radius.circular(isSentByMe ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.textContent ?? '',
              style: TextStyle(
                color: isSentByMe ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isSentByMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Voice Bubble ───────────────────────────────────────────────────────────────

class _VoiceBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;
  final VoidCallback? onPlay;

  const _VoiceBubble(
      {required this.message, required this.isSentByMe, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentColor = const Color(0xFF005C4B);
    final receivedColor = theme.brightness == Brightness.dark
        ? const Color(0xFF1F2C34)
        : Colors.white;

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isSentByMe ? 40 : 8,
          right: isSentByMe ? 8 : 40,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSentByMe ? sentColor : receivedColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isSentByMe ? 12 : 2),
            bottomRight: Radius.circular(isSentByMe ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onPlay,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSentByMe
                          ? Colors.white.withValues(alpha: 0.2)
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: isSentByMe
                          ? Colors.white
                          : theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Waveform decoration
                Row(
                  children: List.generate(
                    18,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 2.5,
                      height: _barHeight(i),
                      decoration: BoxDecoration(
                        color: isSentByMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : theme.colorScheme.primary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (message.transcript != null && message.transcript!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.translate_rounded,
                        size: 12,
                        color: isSentByMe
                            ? Colors.white70
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        message.transcript!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isSentByMe
                              ? Colors.white70
                              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: isSentByMe
                      ? Colors.white.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _barHeight(int index) {
    final heights = [
      8.0, 14.0, 20.0, 12.0, 24.0, 10.0, 18.0, 28.0, 14.0,
      22.0, 8.0, 16.0, 24.0, 12.0, 20.0, 10.0, 18.0, 8.0
    ];
    return heights[index % heights.length];
  }
}

// ── Processing Bubble ──────────────────────────────────────────────────────────

class _ProcessingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 60, right: 8, top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF005C4B),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation(Colors.white70),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyzing voice note...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Sarvam AI + Claude Triage',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final h = time.hour > 12 ? time.hour - 12 : time.hour == 0 ? 12 : time.hour;
  final m = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $period';
}

class _DoctorSuggestionBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSentByMe;

  const _DoctorSuggestionBubble({required this.message, required this.isSentByMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF0F3E32) : const Color(0xFFE8F5E9);
    final borderColor = const Color(0xFF2E7D32);
    final titleColor = const Color(0xFF1B5E20);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 60, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_services_rounded, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Doctor Recommendation',
                      style: TextStyle(
                        color: isDark ? Colors.green[200] : titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.textContent ?? 'No prescriptions suggested yet.',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color: isDark ? Colors.green[300] : Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ],
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
