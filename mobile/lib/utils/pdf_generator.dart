import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';


class PDFGenerator {
  static Future<void> generateAndPrintReport(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final formattedDate = formatter.format(now);

    final int total = docs.length;
    final double average = docs.fold(0, (sum, doc) => sum + (doc['score'] as int)) / total;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'AutoMark - Student Results Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
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
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Student Name', 'Score (%)'],
            data: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unnamed';
              final score = data['score'] ?? 0;
              return [name.toString(), score.toString()];
            }).toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );

    // Save the PDF
    final directory = await getExternalStorageDirectory();
    final downloadsDir = Directory("${directory!.path}/AutoMarkReports");

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final fileName = "automark_report_${now.millisecondsSinceEpoch}.pdf";
    final filePath = "${downloadsDir.path}/$fileName";

    // Ask for permissions if needed
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    //Get current user before saving metadata
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('No logged-in user.');

    // Save metadata to Firestore "downloads" collection
    await FirebaseFirestore.instance.collection('downloads').add({
      'title': fileName,
      'filePath': filePath,
      'timestamp': Timestamp.now(),
      'userId': currentUser.uid,
    });
  }
}
