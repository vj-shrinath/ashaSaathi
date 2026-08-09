import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/gramnidan_register.dart';
import '../../presentation/screens/gramnidan_module_definitions.dart';

class PdfGenerationService {
  static Future<Uint8List> generateRegisterPdf(GramNidanRegister register) async {
    final pdf = pw.Document();

    // Map module definitions for easy lookup
    final Map<String, GramNidanModuleDef> moduleDefs = {};
    for (var m in GramNidanModuleDefinitions.modules) {
      moduleDefs[m.id] = m;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            margin: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('GramNidan Health Register', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#075E54'))),
                    pw.SizedBox(height: 4),
                    pw.Text('ASHA ID: ${register.ashaId}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: ${register.createdAt.toIso8601String().split('T')[0]}', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Time: ${register.createdAt.hour}:${register.createdAt.minute.toString().padLeft(2, '0')}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final List<pw.Widget> content = [];

          // Subject Info
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F3F4F6'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                children: [
                  pw.Text('Subject: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(register.patientName, style: const pw.TextStyle(fontSize: 14)),
                  pw.Spacer(),
                  pw.Text('Type: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(register.displayName, style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
          );
          content.add(pw.SizedBox(height: 20));

          // Modules
          for (var entry in register.moduleData.entries) {
            final moduleId = entry.key;
            final fieldsMap = entry.value;
            final def = moduleDefs[moduleId];

            if (def == null) continue;

            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Module Header
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#075E54'),
                      ),
                      child: pw.Text('${def.icon} ${def.title}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                    ),
                    // Fields
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Table(
                        columnWidths: {
                          0: const pw.FlexColumnWidth(1),
                          1: const pw.FlexColumnWidth(2),
                        },
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        children: def.fields.map((fieldDef) {
                          final value = fieldsMap[fieldDef.id] ?? '-';
                          final isWarning = value.contains('⚠️');
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(fieldDef.label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  value,
                                  style: pw.TextStyle(
                                    color: isWarning ? PdfColors.red800 : PdfColors.black,
                                    fontWeight: isWarning ? pw.FontWeight.bold : pw.FontWeight.normal,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
            content.add(pw.SizedBox(height: 10));
          }

          // Transcript
          if (register.transcript != null && register.transcript!.isNotEmpty) {
            content.add(pw.SizedBox(height: 20));
            content.add(pw.Text('Voice Recording Transcript', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)));
            content.add(pw.SizedBox(height: 4));
            content.add(pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColors.grey100,
              ),
              child: pw.Text('"${register.transcript!}"', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10, color: PdfColors.grey800)),
            ));
          }

          return content;
        },
      ),
    );

    return pdf.save();
  }
}
