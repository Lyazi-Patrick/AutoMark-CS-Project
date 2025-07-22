// NEW: DownloadsScreen for listing and opening generated PDF reports
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FileSystemEntity> _pdfFiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPDFFiles();
  }

  Future<void> _loadPDFFiles() async {
    setState(() => _loading = true);
    final directory = await getExternalStorageDirectory();
    final downloadsDir = Directory("${directory!.path}/AutoMarkReports");
    if (await downloadsDir.exists()) {
      final files =
          downloadsDir
              .listSync()
              .where((f) => f.path.toLowerCase().endsWith('.pdf'))
              .toList()
            ..sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
            );
      setState(() {
        _pdfFiles = files;
        _loading = false;
      });
    } else {
      setState(() {
        _pdfFiles = [];
        _loading = false;
      });
    }
  }

  void _openPDF(FileSystemEntity file) async {
    if (await File(file.path).exists()) {
      await OpenFile.open(file.path);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File not found. Refreshing list.')),
        );
        _loadPDFFiles();
      }
    }
  }

  void _deletePDF(FileSystemEntity file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete PDF'),
            content: Text(
              'Are you sure you want to delete "${file.path.split('/').last}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm == true) {
      try {
        await file.delete();
        _loadPDFFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted ${file.path.split('/').last}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete PDF: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads'), centerTitle: true),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _pdfFiles.isEmpty
              ? const Center(child: Text('No PDF reports found.'))
              : ListView.separated(
                itemCount: _pdfFiles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = _pdfFiles[index];
                  final fileName = file.path.split('/').last;
                  final modified = file.statSync().modified;
                  return ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                    ),
                    title: Text(fileName),
                    subtitle: Text('Saved: ${modified.toLocal()}'),
                    onTap: () => _openPDF(file),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () => _deletePDF(file),
                    ),
                  );
                },
              ),
    );
  }
}
