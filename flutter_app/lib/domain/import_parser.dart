import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'shipment.dart';
import 'validation.dart';

/// Columns of the import file (same template as the prototype).
const List<String> kTemplateFields = [
  'kind',
  'custom',
  'contents',
  'length_cm',
  'width_cm',
  'height_cm',
  'weight_kg',
  'quantity',
  'priority',
  'orientation',
  'fragile',
  'floor_only',
  'stackable',
  'stacking',
  'load_bearing_kg',
];

class ParsedRow {
  final int line; // 1-based row number in the file
  final BoxGroup? group;
  final Map<String, String> errors; // field -> error key
  const ParsedRow(this.line, this.group, this.errors);
  bool get ok => group != null && errors.isEmpty;
}

/// Reads .csv or .xlsx bytes into rows of text cells.
List<List<String>> readTable(String fileName, Uint8List bytes) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.xlsx')) return xlsxRows(bytes);
  return csvRows(utf8.decode(bytes, allowMalformed: true));
}

// ---------- CSV ----------

List<List<String>> csvRows(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split('\n').first;
  final sep = (firstLine.contains(';') && !firstLine.contains(',')) ? ';' : ',';
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == sep) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

// ---------- XLSX (zip + XML, first sheet only) ----------

Map<String, Uint8List> _unzip(Uint8List data) {
  final bd = ByteData.sublistView(data);
  // Find "end of central directory" record
  var eocd = -1;
  for (var i = data.length - 22; i >= 0 && i >= data.length - 70000; i--) {
    if (bd.getUint32(i, Endian.little) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw const FormatException('not a zip file');
  final count = bd.getUint16(eocd + 10, Endian.little);
  var p = bd.getUint32(eocd + 16, Endian.little);
  final out = <String, Uint8List>{};
  for (var n = 0; n < count; n++) {
    if (bd.getUint32(p, Endian.little) != 0x02014b50) break;
    final method = bd.getUint16(p + 10, Endian.little);
    final compSize = bd.getUint32(p + 20, Endian.little);
    final nameLen = bd.getUint16(p + 28, Endian.little);
    final extraLen = bd.getUint16(p + 30, Endian.little);
    final commentLen = bd.getUint16(p + 32, Endian.little);
    final localOffset = bd.getUint32(p + 42, Endian.little);
    final name = utf8.decode(data.sublist(p + 46, p + 46 + nameLen));
    final lNameLen = bd.getUint16(localOffset + 26, Endian.little);
    final lExtraLen = bd.getUint16(localOffset + 28, Endian.little);
    final start = localOffset + 30 + lNameLen + lExtraLen;
    final raw = data.sublist(start, start + compSize);
    if (method == 0) {
      out[name] = raw;
    } else if (method == 8) {
      out[name] = Uint8List.fromList(ZLibDecoder(raw: true).convert(raw));
    }
    p += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

String _xmlText(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

int _colIndex(String ref) {
  var n = 0;
  for (final c in ref.codeUnits) {
    if (c < 65 || c > 90) break;
    n = n * 26 + (c - 64);
  }
  return n - 1;
}

List<List<String>> xlsxRows(Uint8List bytes) {
  final files = _unzip(bytes);
  final shared = <String>[];
  final ss = files['xl/sharedStrings.xml'];
  if (ss != null) {
    final xml = utf8.decode(ss);
    final tRe = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
    for (final si in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(xml)) {
      shared.add(_xmlText(tRe.allMatches(si.group(1)!).map((m) => m.group(1)!).join()));
    }
  }
  final sheetNames = files.keys.where((k) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(k)).toList()..sort();
  if (sheetNames.isEmpty) throw const FormatException('no worksheet');
  final sheetKey = sheetNames.contains('xl/worksheets/sheet1.xml') ? 'xl/worksheets/sheet1.xml' : sheetNames.first;
  final xml = utf8.decode(files[sheetKey]!);

  final rows = <List<String>>[];
  final cellRe = RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true);
  final vRe = RegExp(r'<v>(.*?)</v>', dotAll: true);
  final tRe = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
  for (final rm in RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true).allMatches(xml)) {
    final row = <String>[];
    for (final cm in cellRe.allMatches(rm.group(1)!)) {
      final attrs = cm.group(1) ?? '';
      final inner = cm.group(2) ?? '';
      final ref = RegExp(r'r="([A-Z]+)').firstMatch(attrs)?.group(1);
      final type = RegExp(r't="(\w+)"').firstMatch(attrs)?.group(1);
      var value = '';
      if (type == 'inlineStr') {
        value = _xmlText(tRe.allMatches(inner).map((m) => m.group(1)!).join());
      } else {
        final v = vRe.firstMatch(inner)?.group(1) ?? '';
        if (type == 's') {
          final i = int.tryParse(v);
          value = (i != null && i < shared.length) ? shared[i] : '';
        } else if (type == 'b') {
          value = v == '1' ? 'true' : 'false';
        } else {
          value = _xmlText(v);
        }
      }
      final col = ref == null ? row.length : _colIndex(ref);
      while (row.length < col) {
        row.add('');
      }
      if (col < row.length) {
        row[col] = value;
      } else {
        row.add(value);
      }
    }
    rows.add(row);
  }
  return rows;
}

// ---------- Rows -> groups ----------

bool? _bool(String s) {
  final v = s.trim().toLowerCase();
  if (v.isEmpty) return null;
  if (['true', 'yes', 'y', '1', 'نعم'].contains(v)) return true;
  if (['false', 'no', 'n', '0', 'لا'].contains(v)) return false;
  return null;
}

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

List<ParsedRow> parseTable(List<List<String>> rows, {Iterable<String> usedCodes = const []}) {
  if (rows.isEmpty) return const [];
  final head = rows.first.map((c) => c.trim().toLowerCase()).toList();
  final hasHead = head.contains('length_cm');
  int idx(String f) => hasHead ? head.indexOf(f) : kTemplateFields.indexOf(f);

  final used = usedCodes.toSet();
  final out = <ParsedRow>[];
  for (var r = hasHead ? 1 : 0; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.trim().isEmpty)) continue;
    String cell(String f) {
      final i = idx(f);
      return (i >= 0 && i < row.length) ? row[i].trim() : '';
    }

    final errs = <String, String>{};
    double need(String f, String key) {
      final v = _num(cell(f));
      if (v == null) errs[key] = cell(f).isEmpty ? 'errRequired' : 'errNumber';
      return v ?? 0;
    }

    final kind = cell('kind').toLowerCase();
    final l = need('length_cm', 'length');
    final w = need('width_cm', 'width');
    final h = need('height_cm', 'height');
    final kg = need('weight_kg', 'weight');
    final qty = need('quantity', 'quantity');
    final pr = need('priority', 'priority');
    if (qty != qty.roundToDouble()) errs['quantity'] = 'errWhole';
    if (pr != pr.roundToDouble()) errs['priority'] = 'errPriority';
    final orientRaw = cell('orientation').toLowerCase();
    final fragile = _bool(cell('fragile')) ?? false;
    final stackable = _bool(cell('stackable')) ?? !fragile;
    final stackRaw = cell('stacking').toLowerCase();
    final lbText = cell('load_bearing_kg');
    final lb = lbText.isEmpty ? null : _num(lbText);
    if (lbText.isNotEmpty && lb == null) errs['loadBearing'] = 'errNumber';

    final code = nextGroupCode(used);
    final g = BoxGroup(
      code: code,
      kind: kind,
      custom: cell('custom'),
      contents: cell('contents'),
      lengthMm: (l * 10).round(),
      widthMm: (w * 10).round(),
      heightMm: (h * 10).round(),
      weightKg: kg,
      quantity: qty.round(),
      priority: pr.round(),
      orientation: orientRaw.isEmpty ? 'any' : orientRaw,
      fragile: fragile,
      floorOnly: _bool(cell('floor_only')) ?? false,
      stackable: stackable,
      stacking: stackRaw.isEmpty ? 'any' : stackRaw,
      loadBearingKg: stackable ? lb : null,
    );
    groupErrors(g).forEach((k, v) => errs.putIfAbsent(k, () => v));
    if (errs.isEmpty) used.add(code);
    out.add(ParsedRow(r + 1, errs.isEmpty ? g : null, errs));
  }
  return out;
}
