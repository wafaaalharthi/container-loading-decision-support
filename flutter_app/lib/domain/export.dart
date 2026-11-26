import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart' show PdfColor, PdfColors, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../core/strings.dart';
import 'planning.dart';
import 'shipment.dart';

String _csvCell(Object? v) {
  final s = '${v ?? ''}';
  return (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// Loading sequence + unplaced boxes as CSV (UTF-8 with BOM so Excel shows Arabic).
Uint8List planCsv(Shipment s, PlanOutcome o, Map<String, BoxGroup> groups, String lang) {
  final rows = planCsvRows(o, groups, lang);
  final text = rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
}

/// Table rows of the CSV (first row = header).
List<List<Object?>> planCsvRows(PlanOutcome o, Map<String, BoxGroup> groups, String lang) {
  final rows = <List<Object?>>[
    ['step', 'box_id', 'group', 'contents', 'status', 'x_mm', 'y_mm', 'z_mm', 'length_mm', 'width_mm', 'height_mm', 'reason'],
  ];
  for (var i = 0; i < o.placed.length; i++) {
    final p = o.placed[i];
    rows.add([i + 1, p.id, p.group, groups[p.group]?.contents ?? '', 'loaded', p.x, p.y, p.z, p.dx, p.dy, p.dz, '']);
  }
  for (final e in o.unplaced.entries) {
    final code = e.key.split('-').length >= 2 ? e.key.split('-')[1] : '';
    rows.add(['', e.key, code, groups[code]?.contents ?? '', 'not_loaded', '', '', '', '', '', '', translate(lang, e.value)]);
  }
  return rows;
}

// Built-in PDF fonts are Latin-1 only, so keep the text plain ASCII
String _en(String key, [Map<String, Object>? a]) =>
    translate('en', key, a).replaceAll('\u2013', '-').replaceAll('\u00b7', '-').replaceAll('\u2026', '...');

/// Plan report as PDF (English labels; box IDs and numbers are language-neutral).
Future<Uint8List> planPdf(Shipment s, PlanOutcome o, Map<String, BoxGroup> groups, Uint8List? viewPng) async {
  const accent = PdfColor.fromInt(0xFF2F6BFF);
  final c = s.container;
  final doc = pw.Document(title: 'Loading plan ${s.code}', author: 'Senior Project 1');
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');

  final metrics = <List<String>>[
    ['Space utilization', '${o.utilization.toStringAsFixed(1)} %'],
    ['Loaded boxes', '${o.placed.length} of ${o.total}'],
    ['Not loaded', '${o.unplaced.length}'],
    ['Loaded weight', '${o.weightKg.toStringAsFixed(0)} kg of ${c.payloadKg.toStringAsFixed(0)} kg'],
    ['Boxes blocking unloading', o.blockingPct == null ? '-' : '${o.blockingPct!.toStringAsFixed(1)} %'],
    ['Independent validator', o.valid ? 'Valid (all handling rules met)' : '${o.issues} problems'],
    ['Planning time', o.timeMs < 1000 ? '${o.timeMs.toStringAsFixed(0)} ms' : '${(o.timeMs / 1000).toStringAsFixed(1)} s'],
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text('Senior Project 1 - Loading plan report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: accent)),
        pw.SizedBox(height: 4),
        pw.Text('Shipment ${s.code} - ${_en(c.titleKey)} - ${_en('mode_${o.mode}')} (${o.algorithm})'),
        pw.Text(
            'Inside ${c.length} x ${c.width} x ${c.height} mm - door ${c.doorWidth} x ${c.doorHeight} mm - '
            '${now.year}/${two(now.month)}/${two(now.day)} ${two(now.hour)}:${two(now.minute)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          data: metrics,
          cellStyle: const pw.TextStyle(fontSize: 10),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
        ),
        if (viewPng != null) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            color: const PdfColor.fromInt(0xFF0D1630),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Center(child: pw.Image(pw.MemoryImage(viewPng), height: 230)),
          ),
          pw.Text('x = 0 is the back wall; the door is at x = length. Steps follow the loading order.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
        pw.SizedBox(height: 12),
        pw.Text('Loading sequence', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: ['Step', 'Box ID', 'x', 'y', 'z', 'L x W x H (mm)'],
          data: [
            for (var i = 0; i < o.placed.length; i++)
              [
                '${i + 1}',
                o.placed[i].id,
                '${o.placed[i].x}',
                '${o.placed[i].y}',
                '${o.placed[i].z}',
                '${o.placed[i].dx} x ${o.placed[i].dy} x ${o.placed[i].dz}',
              ],
          ],
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: accent),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        ),
        if (o.unplaced.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Boxes not loaded (${o.unplaced.length})',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Box ID', 'Reason'],
            data: [
              for (final e in o.unplaced.entries) [e.key, _en(e.value)],
            ],
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: accent),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
