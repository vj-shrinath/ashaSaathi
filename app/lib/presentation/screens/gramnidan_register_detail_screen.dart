import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../core/models/gramnidan_register.dart';
import '../widgets/gramnidan_module_card.dart';
import '../screens/gramnidan_module_definitions.dart';

class GramNidanRegisterDetailScreen extends StatelessWidget {
  final String registerId;

  const GramNidanRegisterDetailScreen({super.key, required this.registerId});

  Future<GramNidanRegister?> _loadRegister() async {
    final response = await Supabase.instance.client
        .from('gramnidan_registers')
        .select()
        .eq('id', registerId)
        .maybeSingle();

    if (response == null) return null;
    return GramNidanRegister.fromMap(response);
  }

  Future<void> _downloadAndShowPdf(BuildContext context, String urlString, String registerName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading PDF...'), duration: Duration(seconds: 2)),
      );
      
      final response = await http.get(Uri.parse(urlString));
      if (response.statusCode == 200) {
        await Printing.sharePdf(
          bytes: response.bodyBytes,
          filename: '${registerName.replaceAll(' ', '_')}_report.pdf',
        );
      } else {
        throw Exception('Failed to download PDF');
      }
    } catch (e) {
      debugPrint('Could not download PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to open PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GramNidanRegister?>(
      future: _loadRegister(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final register = snapshot.data;
        if (register == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Register Details')),
            body: const Center(child: Text('Register not found')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            title: Text(register.displayName),
            actions: [
              if (register.pdfUrl != null)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'View PDF',
                  onPressed: () => _downloadAndShowPdf(context, register.pdfUrl!, register.displayName),
                )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(register: register),
                const SizedBox(height: 16),
                const Text(
                  'REGISTER DATA',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                ),
                const SizedBox(height: 8),
                // Render modules
                ...GramNidanModuleDefinitions.modules
                    .where((m) => register.moduleData.containsKey(m.id))
                    .map((module) => GramNidanModuleCard(
                          module: module,
                          filledFields: register.moduleData[module.id] ?? {},
                          startExpanded: true,
                        )),
                const SizedBox(height: 16),
                if (register.transcript != null) ...[
                  const Text(
                    'ORIGINAL VOICE TRANSCRIPT',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '"${register.transcript}"',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final GramNidanRegister register;

  const _HeaderCard({required this.register});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: register.isWarning
            ? Border.all(color: Colors.orange.shade800, width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(register.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      register.patientName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ASHA ID: ${register.ashaId}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (register.isWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This register contains flagged medical warnings that require attention.',
                      style: TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.w500),
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
}
