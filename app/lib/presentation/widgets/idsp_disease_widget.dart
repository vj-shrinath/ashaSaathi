import 'package:flutter/material.dart';

class IdspDiseaseWidget extends StatefulWidget {
  final void Function(Map<String, String>) onDataChanged;

  const IdspDiseaseWidget({super.key, required this.onDataChanged});

  @override
  State<IdspDiseaseWidget> createState() => _IdspDiseaseWidgetState();
}

class _IdspDiseaseWidgetState extends State<IdspDiseaseWidget> {
  bool _hasCases = false;
  String? _selectedDisease;
  final _data = <String, String>{};

  static const _diseases = [
    {'id': 'malaria', 'name': 'Malaria 🦟'},
    {'id': 'dengue', 'name': 'Dengue 🩸'},
    {'id': 'tb', 'name': 'Tuberculosis 🫁'},
    {'id': 'typhoid', 'name': 'Typhoid 🤢'},
  ];

  void _updateParent() {
    if (!_hasCases) {
      widget.onDataChanged({'hascase': 'NO'});
    } else {
      widget.onDataChanged({
        'hascase': 'YES',
        'diseasename': _selectedDisease ?? 'Unknown',
        ..._data,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCases) {
      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Text('🦟', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Text('IDSP Communicable Disease', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _hasCases = false);
                      _updateParent();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('✅ NO', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _hasCases = true);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('⚠️ YES'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Zero Active Cases Reported', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.red.shade50,
      shape: Border.all(color: Colors.red.shade200),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('⚠️ High Priority Infection Alert', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _hasCases = false;
                      _selectedDisease = null;
                      _data.clear();
                    });
                    _updateParent();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _diseases.map((d) {
                final isSelected = _selectedDisease == d['id'];
                return ChoiceChip(
                  label: Text(d['name']!),
                  selected: isSelected,
                  selectedColor: Colors.red.shade100,
                  onSelected: (val) {
                    setState(() => _selectedDisease = val ? d['id'] : null);
                    _updateParent();
                  },
                );
              }).toList(),
            ),
            if (_selectedDisease != null) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Patient Name & Age', border: OutlineInputBorder()),
                onChanged: (v) { _data['patient'] = v; _updateParent(); },
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Symptoms / Date of Onset', border: OutlineInputBorder()),
                onChanged: (v) { _data['symptoms'] = v; _updateParent(); },
              ),
            ]
          ],
        ),
      ),
    );
  }
}
