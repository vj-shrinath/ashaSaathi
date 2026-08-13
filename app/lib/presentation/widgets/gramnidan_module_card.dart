import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/services/pdf_generation_service.dart';
import '../screens/gramnidan_module_definitions.dart';

class GramNidanModuleCard extends StatefulWidget {
  final GramNidanModuleDef module;
  final Map<String, String> filledFields;
  final bool startExpanded;
  final void Function(String fieldId, String newValue)? onFieldEdited;

  const GramNidanModuleCard({
    super.key,
    required this.module,
    required this.filledFields,
    this.startExpanded = false,
    this.onFieldEdited,
  });

  @override
  State<GramNidanModuleCard> createState() => _GramNidanModuleCardState();
}

class _GramNidanModuleCardState extends State<GramNidanModuleCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;
  }

  void _editField(String fieldId, String currentValue) {
    if (widget.onFieldEdited == null) return;
    
    final label = widget.module.fields.firstWhere((f) => f.id == fieldId, orElse: () => GramNidanFieldDef(fieldId, fieldId)).label;
    final controller = TextEditingController(text: currentValue.replaceAll('⚠️ ', '').trim());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onFieldEdited!(fieldId, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWarning = widget.filledFields.values.any((v) => v.contains('⚠️'));
    final isAutoFilled = widget.filledFields.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasWarning ? BorderSide(color: Colors.orange.shade800, width: 1.5) : BorderSide.none,
      ),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                borderRadius: _expanded ? const BorderRadius.vertical(top: Radius.circular(12)) : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(widget.module.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.module.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (widget.module.id == 'idsp')
                          const Text(
                            'Malaria, TB, Leprosy — village surveillance',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  if (isAutoFilled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'AUTO ✓',
                        style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121B22) : const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  widget.module.id == 'idsp'
                      ? _IdspCustomModuleWidget(
                          filledFields: widget.filledFields,
                          onFieldEdited: widget.onFieldEdited,
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: widget.module.fields.length,
                          itemBuilder: (context, i) {
                            final fieldDef = widget.module.fields[i];
                            final value = widget.filledFields[fieldDef.id] ?? '— (fill karo)';
                            final isWarningField = value.contains('⚠️');
                            final isEmptyFallback = value == '— (fill karo)';

                            return InkWell(
                              onTap: () => _editField(fieldDef.id, isEmptyFallback ? '' : value),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isWarningField
                                      ? Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1)
                                      : (isDark ? const Color(0xFF202C33) : Colors.white),
                                  border: Border.all(
                                    color: isWarningField ? Colors.orange.shade700 : Colors.grey.withValues(alpha: 0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      fieldDef.label,
                                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      value,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isWarningField ? FontWeight.bold : FontWeight.w500,
                                        fontStyle: isEmptyFallback ? FontStyle.italic : FontStyle.normal,
                                        color: isWarningField
                                            ? (isDark ? Colors.orange[300] : Colors.orange[900])
                                            : (isEmptyFallback
                                                ? Colors.grey
                                                : (isDark ? Colors.white : Colors.black87)),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 12),
                  // Action buttons at bottom of every register module
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final pdfBytes = await PdfGenerationService.generateModulePdf(
                              module: widget.module,
                              filledFields: widget.filledFields,
                            );
                            await Printing.layoutPdf(
                              onLayout: (format) async => pdfBytes,
                              name: '${widget.module.id}_register_report.pdf',
                            );
                          },
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('💾 Save PDF / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final pdfBytes = await PdfGenerationService.generateModulePdf(
                              module: widget.module,
                              filledFields: widget.filledFields,
                            );
                            await Printing.sharePdf(
                              bytes: pdfBytes,
                              filename: '${widget.module.id}_register_report.pdf',
                            );
                          },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('📲 MO ko Bhejo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A4F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
}

// ── Custom IDSP Interactive Widget matching demo ────────────────────────────
class _IdspCustomModuleWidget extends StatefulWidget {
  final Map<String, String> filledFields;
  final void Function(String fieldId, String newValue)? onFieldEdited;

  const _IdspCustomModuleWidget({
    required this.filledFields,
    this.onFieldEdited,
  });

  @override
  State<_IdspCustomModuleWidget> createState() => _IdspCustomModuleWidgetState();
}

class _IdspCustomModuleWidgetState extends State<_IdspCustomModuleWidget> {
  late bool _hasCases;
  String? _selectedDisease;

  static const _diseases = [
    {'id': 'malaria', 'name': 'Malaria 🦟'},
    {'id': 'dengue', 'name': 'Dengue 🩸'},
    {'id': 'tb', 'name': 'Tuberculosis 🫁'},
    {'id': 'leprosy', 'name': 'Leprosy 🖐️'},
    {'id': 'typhoid', 'name': 'Typhoid 🤢'},
  ];

  @override
  void initState() {
    super.initState();
    final val = widget.filledFields['hascase'] ?? widget.filledFields['diseasetype'];
    _hasCases = val != null && val != 'NO' && val.isNotEmpty && val != '— (fill karo)';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notice bar
        Row(
          children: [
            const Text('📑 ', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Text(
                'IDSP Surveillance — NO/YES toggle se shuru karo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.purple[200] : const Color(0xFF6B21A8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Question label
        const Text(
          'Any History / Symptoms of Communicable Disease in Family?',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Side-by-side NO / YES toggle buttons
        Row(
          children: [
            // NO - Healthy Household
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _hasCases = false);
                  widget.onFieldEdited?.call('diseasetype', 'NO');
                  widget.onFieldEdited?.call('hascase', 'NO');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_hasCases ? const Color(0xFF2D6A4F) : (isDark ? const Color(0xFF202C33) : Colors.white),
                  foregroundColor: !_hasCases ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                  elevation: !_hasCases ? 2 : 0,
                  side: BorderSide(
                    color: !_hasCases ? const Color(0xFF2D6A4F) : Colors.grey.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '❌ NO - Healthy Household',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // YES - Record Disease History / Case
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _hasCases = true);
                  widget.onFieldEdited?.call('hascase', 'YES');
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: _hasCases ? Colors.red.shade700 : (isDark ? const Color(0xFF202C33) : Colors.white),
                  foregroundColor: _hasCases ? Colors.white : const Color(0xFFD97706),
                  side: BorderSide(
                    color: _hasCases ? Colors.red.shade700 : Colors.amber.shade600.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '⚠️ YES - Record Disease Case',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // When NO is selected: show Zero Active Cases + Portal Output
        if (!_hasCases) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9),
              border: Border.all(color: isDark ? const Color(0xFF2D6A4F) : const Color(0xFFA5D6A7)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_box_rounded, color: isDark ? Colors.green[300] : const Color(0xFF2D6A4F), size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Zero Active Cases Reported (IDSP Compliant)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green[200] : const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '1-tap save neeche "💾 Save PDF (App)" button se ho jayega.',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.green[100]?.withValues(alpha: 0.8) : Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2418) : const Color(0xFFFFF8E1),
              border: Border.all(color: isDark ? const Color(0xFF5D4037) : const Color(0xFFFFECB3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('📄 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    'Portal Output: Taluka Health Officer (THO) auto-alert if cluster cases spike',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // When YES is selected: show disease choice chips & input options
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF321A1A) : Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Identified Disease / Symptoms:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _diseases.map((d) {
                    final isSel = _selectedDisease == d['id'];
                    return ChoiceChip(
                      label: Text(d['name']!, style: const TextStyle(fontSize: 11)),
                      selected: isSel,
                      selectedColor: Colors.red.shade100,
                      onSelected: (val) {
                        setState(() => _selectedDisease = val ? d['id'] : null);
                        widget.onFieldEdited?.call('diseasetype', d['name']!);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                
                // Fields grid for patient details
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: GramNidanModuleDefinitions.modules
                      .firstWhere((m) => m.id == 'idsp')
                      .fields
                      .length,
                  itemBuilder: (context, i) {
                    final fieldDef = GramNidanModuleDefinitions.modules
                        .firstWhere((m) => m.id == 'idsp')
                        .fields[i];
                    final value = widget.filledFields[fieldDef.id] ?? '— (fill karo)';
                    final isEmptyFallback = value == '— (fill karo)';

                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202C33) : Colors.white,
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            fieldDef.label,
                            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: isEmptyFallback ? FontStyle.italic : FontStyle.normal,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
