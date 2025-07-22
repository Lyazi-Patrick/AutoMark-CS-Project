import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'marked_scripts_utils.dart'; // NEW: Import shared marked scripts utils

// NEW: Helper to fetch marked scripts
Future<List<QueryDocumentSnapshot>> fetchMarkedScripts() async {
  final snapshot = await getMarkedScriptsQuery().get();
  return snapshot.docs;
}

class PDFGenerator {
  static Future<void> generateAndPrintReport() async {
    final docs = await fetchMarkedScripts();
    final pdf = pw.Document();
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final formattedDate = formatter.format(now);

    // Only include docs with valid numeric score and total > 0
    final validDocs =
        docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final score = data['score'];
          final totalScore = data['total'];
          return (score is num) && (totalScore is num) && totalScore > 0;
        }).toList();

    final int total = validDocs.length;
    final double average =
        total > 0
            ? validDocs.fold<num>(0, (sum, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final score =
                      (data['score'] is num) ? data['score'] as num : 0;
                  final totalScore =
                      (data['total'] is num) ? data['total'] as num : 0;
                  return sum + ((score / totalScore) * 100);
                }) /
                total
            : 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              pw.Center(
                child: pw.Text(
                  'AutoMark - Student Results Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: $formattedDate'),
              pw.SizedBox(height: 20),
              pw.Text('Total Submissions: $total'),
              pw.Text('Average Score: ${average.toStringAsFixed(1)}%'),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text(
                'Student Scores:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Student Name', 'Score (%)'],
                data:
                    validDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unnamed';
                      final score =
                          (data['score'] is num) ? data['score'] as num : 0;
                      final totalScore =
                          (data['total'] is num) ? data['total'] as num : 0;
                      final percent =
                          (totalScore > 0)
                              ? ((score / totalScore) * 100).toStringAsFixed(1)
                              : '0.0';
                      return [name.toString(), '$percent%'];
                    }).toList(),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 12),
              ),
            ],
      ),
    );

    // Get external directory
    final directory = await getExternalStorageDirectory();
    final downloadsDir = Directory("${directory!.path}/AutoMarkReports");

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final filePath =
        "${downloadsDir.path}/automark_report_${now.millisecondsSinceEpoch}.pdf";

    // Ask for permissions if needed
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
  }
}
