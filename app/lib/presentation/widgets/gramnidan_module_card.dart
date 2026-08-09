import 'package:flutter/material.dart';
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
    if (widget.filledFields.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWarning = widget.filledFields.values.any((v) => v.contains('⚠️'));

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
                    child: Text(
                      widget.module.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
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
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: widget.filledFields.length,
                itemBuilder: (context, i) {
                  final entry = widget.filledFields.entries.elementAt(i);
                  final fieldDef = widget.module.fields.firstWhere((f) => f.id == entry.key, orElse: () => GramNidanFieldDef(entry.key, entry.key));
                  final isWarningField = entry.value.contains('⚠️');

                  return InkWell(
                    onTap: () => _editField(entry.key, entry.value),
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
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isWarningField ? FontWeight.bold : FontWeight.w500,
                              color: isWarningField
                                  ? (isDark ? Colors.orange[300] : Colors.orange[900])
                                  : (isDark ? Colors.white : Colors.black87),
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
            ),
        ],
      ),
    );
  }
}
