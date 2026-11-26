import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/shipment_repository.dart';
import '../../domain/shipment.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'shipment_screen.dart' show confirmDialog;

/// Add or edit one box group.
class GroupEditorScreen extends StatefulWidget {
  final int shipmentId;
  final List<BoxGroup> existing;
  final BoxGroup? group; // null = new group
  const GroupEditorScreen({super.key, required this.shipmentId, required this.existing, this.group});

  @override
  State<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<GroupEditorScreen> {
  final _repo = ShipmentRepository();
  final _form = GlobalKey<FormState>();
  late final String _code;
  late String _kind;
  late String _orientation;
  late bool _fragile, _floorOnly, _stackable;
  late String _stacking;
  late final TextEditingController _custom, _contents, _l, _w, _h, _kg, _qty, _prio, _lb;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _code = g?.code ?? nextGroupCode(widget.existing.map((e) => e.code));
    _kind = g?.kind ?? 'other';
    _orientation = g?.orientation ?? 'any';
    _fragile = g?.fragile ?? false;
    _floorOnly = g?.floorOnly ?? false;
    _stackable = g?.stackable ?? true;
    _stacking = g?.stacking ?? 'any';
    _custom = TextEditingController(text: g?.custom ?? '');
    _contents = TextEditingController(text: g?.contents ?? '');
    _l = TextEditingController(text: g == null ? '' : mmToCm(g.lengthMm));
    _w = TextEditingController(text: g == null ? '' : mmToCm(g.widthMm));
    _h = TextEditingController(text: g == null ? '' : mmToCm(g.heightMm));
    _kg = TextEditingController(text: g == null ? '' : _trim(g.weightKg));
    _qty = TextEditingController(text: g == null ? '' : '${g.quantity}');
    _prio = TextEditingController(text: g == null ? '1' : '${g.priority}');
    _lb = TextEditingController(text: g?.loadBearingKg == null ? '' : _trim(g!.loadBearingKg!));
  }

  static String _trim(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    for (final c in [_custom, _contents, _l, _w, _h, _kg, _qty, _prio, _lb]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  // Field validators return a translated message or null
  String? _positive(String? v, {double max = double.infinity}) {
    final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if ((v ?? '').trim().isEmpty) return context.tr('errRequired');
    if (n == null) return context.tr('errNumber');
    if (n <= 0) return context.tr('errPositive');
    if (n > max) return context.tr('errTooLarge');
    return null;
  }

  String? _whole(String? v, int min, int max, String errKey) {
    final n = int.tryParse((v ?? '').trim());
    if ((v ?? '').trim().isEmpty) return context.tr('errRequired');
    if (n == null || n < min) return context.tr(errKey);
    if (n > max) return context.tr('errTooLarge');
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final lb = _lb.text.trim().isEmpty ? null : _num(_lb);
    final g = BoxGroup(
      id: widget.group?.id,
      code: _code,
      kind: _kind,
      custom: _kind == 'other' ? _custom.text.trim() : '',
      contents: _contents.text.trim(),
      lengthMm: (_num(_l)! * 10).round(),
      widthMm: (_num(_w)! * 10).round(),
      heightMm: (_num(_h)! * 10).round(),
      weightKg: _num(_kg)!,
      quantity: int.parse(_qty.text.trim()),
      priority: int.parse(_prio.text.trim()),
      orientation: _orientation,
      fragile: _fragile,
      floorOnly: _floorOnly,
      stackable: _stackable && !_fragile,
      stacking: _stacking,
      loadBearingKg: (_stackable && !_fragile) ? lb : null,
    );
    await _repo.saveGroup(widget.shipmentId, g);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, context.tr('deleteGroupQ', {'code': _code}), context.tr('delete'));
    if (!ok) return;
    await _repo.deleteGroup(widget.shipmentId, widget.group!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _numField(TextEditingController c, String label, String? Function(String?) validator, {bool decimal = true}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(labelText: context.tr(label)),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
    );
  }

  Widget _switch(String title, String? sub, bool value, ValueChanged<bool>? onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr(title), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: sub == null ? null : Text(context.tr(sub), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.group != null;
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(editing ? 'editGroup' : 'newGroup', {'code': _code})),
        actions: [
          if (editing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: context.tr('category')),
              items: [
                for (final k in kKinds) DropdownMenuItem(value: k, child: Text(context.tr('kind_$k'))),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'other'),
            ),
            if (_kind == 'other') ...[
              gap,
              TextFormField(controller: _custom, decoration: InputDecoration(labelText: context.tr('customKind'))),
            ],
            gap,
            TextFormField(controller: _contents, decoration: InputDecoration(labelText: context.tr('contents'))),
            gap,
            Row(children: [
              Expanded(child: _numField(_l, 'lengthCm', (v) => _positive(v, max: 5000))),
              const SizedBox(width: 8),
              Expanded(child: _numField(_w, 'widthCm', (v) => _positive(v, max: 5000))),
              const SizedBox(width: 8),
              Expanded(child: _numField(_h, 'heightCm', (v) => _positive(v, max: 5000))),
            ]),
            gap,
            Row(children: [
              Expanded(child: _numField(_kg, 'weightKg', (v) => _positive(v))),
              const SizedBox(width: 8),
              Expanded(child: _numField(_qty, 'quantity', (v) => _whole(v, 1, 999, 'errWhole'), decimal: false)),
            ]),
            gap,
            _numField(_prio, 'priority', (v) => _whole(v, 1, 9, 'errPriority'), decimal: false),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(context.tr('priorityHint'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
            SectionTitle(context.tr('orientation')),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'any', label: Text(context.tr('orient_any'))),
                ButtonSegment(value: 'upright', label: Text(context.tr('orient_upright'))),
              ],
              selected: {_orientation},
              onSelectionChanged: (s) => setState(() => _orientation = s.first),
            ),
            const SizedBox(height: 8),
            _switch('fragile', 'fragileSub', _fragile, (v) => setState(() => _fragile = v)),
            _switch('floorOnly', 'floorOnlySub', _floorOnly, (v) => setState(() => _floorOnly = v)),
            _switch('stackable', _fragile ? 'stackLocked' : 'stackSub', _stackable && !_fragile,
                _fragile ? null : (v) => setState(() => _stackable = v)),
            if (_stackable && !_fragile) ...[
              DropdownButtonFormField<String>(
                initialValue: _stacking,
                decoration: InputDecoration(labelText: context.tr('stacking')),
                items: [
                  for (final s in const ['any', 'same', 'other'])
                    DropdownMenuItem(value: s, child: Text(context.tr('stack_$s'))),
                ],
                onChanged: (v) => setState(() => _stacking = v ?? 'any'),
              ),
              gap,
              _numField(_lb, 'loadBearing', (v) => (v ?? '').trim().isEmpty ? null : _positive(v)),
            ],
            const SizedBox(height: 20),
            GradientButton(label: context.tr('save'), icon: Icons.check, busy: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
