import 'package:flutter/material.dart';
import '../../core/models/message_model.dart';

/// Full triage report card for Doctor Dashboard and chat.
class TriageReportCard extends StatelessWidget {
  final TriageResult report;
  final String transcript;
  final bool compact;
  final VoidCallback? onMarkReviewed;
  final VoidCallback? onOpenDoctorSheet;

  const TriageReportCard({
    super.key,
    required this.report,
    required this.transcript,
    this.compact = false,
    this.onMarkReviewed,
    this.onOpenDoctorSheet,
  });

  Color get _riskColor {
    switch (report.riskCategory) {
      case 'Red':
        return const Color(0xFFD32F2F);
      case 'Orange':
        return const Color(0xFFF57C00);
      case 'Yellow':
        return const Color(0xFFFBC02D);
      default:
        return const Color(0xFF388E3C);
    }
  }

  Color get _riskBgColor {
    switch (report.riskCategory) {
      case 'Red':
        return const Color(0xFFFFEBEE);
      case 'Orange':
        return const Color(0xFFFFF3E0);
      case 'Yellow':
        return const Color(0xFFFFFDE7);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  IconData get _riskIcon {
    switch (report.riskCategory) {
      case 'Red':
        return Icons.emergency_rounded;
      case 'Orange':
        return Icons.warning_amber_rounded;
      case 'Yellow':
        return Icons.info_outline_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _riskColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Risk Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _riskBgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(_riskIcon, color: _riskColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${report.riskCategory} Alert — ${report.severity} Severity',
                    style: TextStyle(
                      color: _riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _riskColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Risk ${report.riskScore}/10',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person_outline,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.patientSummary,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Symptoms
                if (report.symptoms.isNotEmpty) ...[
                  Text(
                    'Symptoms',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: report.symptoms.map((s) => Chip(
                      label: Text(s,
                          style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                    )).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // Vitals Row
                if (report.vitals.isNotEmpty) ...[
                  Text(
                    'Vitals',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: report.vitals.entries.take(3).map((e) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        children: [
                          Icon(Icons.thermostat_rounded,
                              size: 14, color: _riskColor),
                          const SizedBox(width: 4),
                          Text(
                            '${e.key}: ${e.value}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // Suggested Action
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.medical_services_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.suggestedAction,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!compact && transcript.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Voice Transcript',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"$transcript"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Action flags
                if (report.emergencyRequired || report.ambulanceRecommendation)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        if (report.emergencyRequired)
                          _AlertChip(
                              label: '🚨 Emergency Required',
                              color: Colors.red),
                        if (report.ambulanceRecommendation)
                          _AlertChip(
                              label: '🚑 Ambulance Needed',
                              color: Colors.orange),
                      ],
                    ),
                  ),

                if (onMarkReviewed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onMarkReviewed,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Mark as Reviewed'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _riskColor,
                        ),
                      ),
                    ),
                  ),
                if (onOpenDoctorSheet != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onOpenDoctorSheet,
                        icon: const Icon(Icons.assignment_rounded, size: 18),
                        label: const Text('Create doctor sheet from this analysis'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label;
  final Color color;
  const _AlertChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
