import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/shipment_repository.dart';
import '../../domain/import_parser.dart';
import '../../domain/sample.dart';
import '../../domain/shipment.dart';
import '../../domain/validation.dart' show InputStatus;
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'shipment_screen.dart' show GroupTile;

/// Import box groups from .xlsx / .csv, or load the SH-102 sample.
class ImportScreen extends StatefulWidget {
  final int shipmentId;
  final List<BoxGroup> existing;
  const ImportScreen({super.key, required this.shipmentId, required this.existing});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _repo = ShipmentRepository();
  String? _fileName;
  List<List<String>>? _table; // last file read (null for the sample)
  List<ParsedRow> _rows = const [];
  String? _error;
  bool _replace = false;
  bool _busy = false;

  Iterable<String> get _usedCodes => _replace ? const [] : widget.existing.map((g) => g.code);

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      if (!mounted) return;
      final f = res?.files.single;
      if (f == null || f.bytes == null) return;
      final table = readTable(f.name, f.bytes!);
      final rows = parseTable(table, usedCodes: _usedCodes);
      setState(() {
        _fileName = f.name;
        _table = table;
        _rows = rows;
        if (rows.isEmpty) _error = context.tr('importEmpty');
      });
    } catch (e) {
      setState(() => _error = context.tr('importFailed', {'e': e.toString()}));
    }
  }

  void _loadSample() {
    // Renumber the sample codes after the groups already in the shipment
    final used = _usedCodes.toSet();
    final rows = <ParsedRow>[];
    var line = 2;
    for (final g in sh102Groups) {
      final code = used.contains(g.code) ? nextGroupCode(used) : g.code;
      used.add(code);
      rows.add(ParsedRow(line++, g.withCode(code), const {}));
    }
    setState(() {
      _error = null;
      _table = null;
      _fileName = 'SH-102_sample.csv';
      _rows = rows;
    });
  }

  Future<void> _add() async {
    final ok = [for (final r in _rows) if (r.ok) r.group!];
    if (ok.isEmpty) return;
    setState(() => _busy = true);
    await _repo.addGroups(widget.shipmentId, ok, replace: _replace);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('added', {'n': ok.length}))));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final good = _rows.where((r) => r.ok).toList();
    final bad = _rows.where((r) => !r.ok).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('importTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GradientButton(label: context.tr('chooseFile'), icon: Icons.upload_file, onPressed: _pickFile),
          const SizedBox(height: 10),
          OutlineAppButton(label: context.tr('loadSample'), icon: Icons.inventory_2_outlined, onPressed: _loadSample),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('templateNote'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                SelectableText(
                  kTemplateFields.join(', '),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.cyan),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          if (_rows.isNotEmpty) ...[
            SectionTitle(context.tr('importPreview', {'f': _fileName ?? ''})),
            Text(context.tr('rowsOk', {'n': good.length}),
                style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
            if (bad.isNotEmpty)
              Text(context.tr('rowsBad', {'n': bad.length}),
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final r in good) GroupTile(group: r.group!, status: const InputStatus(true)),
            for (final r in bad)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('rowN', {'n': r.line}),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                    for (final e in r.errors.entries)
                      Text('${e.key}: ${context.tr(e.value)}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            if (widget.existing.isNotEmpty)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('replaceExisting')),
                value: _replace,
                onChanged: (v) {
                  setState(() => _replace = v);
                  // Codes depend on the existing groups, so rebuild the preview
                  final t = _table;
                  if (t == null) {
                    _loadSample();
                  } else {
                    setState(() => _rows = parseTable(t, usedCodes: _usedCodes));
                  }
                },
              ),
            const SizedBox(height: 8),
            GradientButton(
              label: context.tr('addRows', {'n': good.length}),
              icon: Icons.check,
              busy: _busy,
              onPressed: good.isEmpty ? null : _add,
            ),
          ],
        ],
      ),
    );
  }
}
