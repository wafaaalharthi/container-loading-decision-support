import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../data/records_repository.dart';
import '../../state/app_state.dart';

/// Android save-as dialog, then record the report and a notification. False if cancelled.
Future<bool> saveExport(AppState app, Uint8List bytes, String name, String kind, int planId, String title) async {
  final path = await FilePicker.platform.saveFile(fileName: name, bytes: bytes);
  if (path == null) return false;
  await ReportRepository().add(app.user!.id, planId, kind, title, fileName: name);
  await NotificationRepository().add(app.user!.id, 'notif_exported', {'name': name});
  return true;
}

/// Shared frame for the PDF and CSV previews: back arrow, Save and Share, hint at the bottom.
class _ExportFrame extends StatefulWidget {
  final String titleKey;
  final Uint8List bytes;
  final String fileName;
  final String kind;
  final String mime;
  final int planId;
  final String title;
  final Widget body;

  const _ExportFrame({
    required this.titleKey,
    required this.bytes,
    required this.fileName,
    required this.kind,
    required this.mime,
    required this.planId,
    required this.title,
    required this.body,
  });

  @override
  State<_ExportFrame> createState() => _ExportFrameState();
}

class _ExportFrameState extends State<_ExportFrame> {
  bool _saved = false;
  bool _saving = false; // the save window is open

  Future<void> _save() async {
    if (_saving) return;
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      if (await saveExport(app, widget.bytes, widget.fileName, widget.kind, widget.planId, widget.title)) {
        if (mounted) setState(() => _saved = true);
        messenger.showSnackBar(SnackBar(content: Text(app.t('exported', {'name': widget.fileName}))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(widget.bytes, mimeType: widget.mime, name: widget.fileName)],
      fileNameOverrides: [widget.fileName],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(widget.titleKey)),
        actions: [
          IconButton(tooltip: context.tr('share'), icon: const Icon(Icons.share_outlined), onPressed: _share),
          TextButton.icon(
            onPressed: (_saved || _saving) ? null : _save,
            icon: Icon(_saved ? Icons.check : Icons.download),
            label: Text(context.tr(_saved ? 'savedToDevice' : 'saveToDevice')),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: widget.body),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              color: AppColors.panel,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.tr('saveHint'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PdfViewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final int planId;
  final String title;
  const PdfViewScreen({super.key, required this.bytes, required this.fileName, required this.planId, required this.title});

  @override
  Widget build(BuildContext context) {
    return _ExportFrame(
      titleKey: 'pdfPreview',
      bytes: bytes,
      fileName: fileName,
      kind: 'pdf',
      mime: 'application/pdf',
      planId: planId,
      title: title,
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: false,
      ),
    );
  }
}

class CsvViewScreen extends StatelessWidget {
  final Uint8List bytes;
  final List<List<Object?>> rows; // first row = header
  final String fileName;
  final int planId;
  final String title;
  const CsvViewScreen({
    super.key,
    required this.bytes,
    required this.rows,
    required this.fileName,
    required this.planId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.cyan);
    const cell = TextStyle(fontSize: 12);
    return _ExportFrame(
      titleKey: 'csvPreview',
      bytes: bytes,
      fileName: fileName,
      kind: 'csv',
      mime: 'text/csv',
      planId: planId,
      title: title,
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 34,
                columnSpacing: 16,
                border: TableBorder.all(color: AppColors.border, width: 0.6),
                columns: [for (final h in rows.first) DataColumn(label: Text('$h', style: head))],
                rows: [
                  for (final r in rows.skip(1))
                    DataRow(cells: [for (final v in r) DataCell(Text('${v ?? ''}', style: cell))]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
