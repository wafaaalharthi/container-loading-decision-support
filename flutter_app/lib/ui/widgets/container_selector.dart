import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/containers.dart';
import '../../state/app_state.dart';

/// Preset cards (20GP / 40GP / 40HC) plus a custom size form.
/// [onChanged] gets null while the custom form is invalid.
class ContainerSelector extends StatefulWidget {
  final ContainerDims initial;
  final ValueChanged<ContainerDims?> onChanged;
  const ContainerSelector({super.key, required this.initial, required this.onChanged});

  @override
  State<ContainerSelector> createState() => _ContainerSelectorState();
}

class _ContainerSelectorState extends State<ContainerSelector> {
  late String _code = widget.initial.code;
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final base = widget.initial.isCustom ? widget.initial : containerPresets.first;
    _c = {
      'l': TextEditingController(text: mmToCm(base.length)),
      'w': TextEditingController(text: mmToCm(base.width)),
      'h': TextEditingController(text: mmToCm(base.height)),
      'dw': TextEditingController(text: mmToCm(base.doorWidth)),
      'dh': TextEditingController(text: mmToCm(base.doorHeight)),
      'p': TextEditingController(text: base.payloadKg.round().toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(String k) {
    final v = double.tryParse(_c[k]!.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  ContainerDims? _custom() {
    final l = _v('l'), w = _v('w'), h = _v('h'), dw = _v('dw'), dh = _v('dh'), p = _v('p');
    if (l == null || w == null || h == null || dw == null || dh == null || p == null) return null;
    if (dw > w || dh > h) return null;
    return ContainerDims(
      code: ContainerDims.customCode,
      length: (l * 10).round(),
      width: (w * 10).round(),
      height: (h * 10).round(),
      doorWidth: (dw * 10).round(),
      doorHeight: (dh * 10).round(),
      payloadKg: p,
    );
  }

  void _emit() => widget.onChanged(_code == ContainerDims.customCode ? _custom() : presetByCode(_code));

  void _select(String code) {
    setState(() => _code = code);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in containerPresets) _card(context, p.code, context.tr(p.titleKey), _details(context, p)),
        _card(context, ContainerDims.customCode, context.tr('cont_custom'), null),
        if (_code == ContainerDims.customCode) _customForm(context),
      ],
    );
  }

  String _details(BuildContext context, ContainerDims c) =>
      '${context.tr('insideDims', {'l': mmToM(c.length), 'w': mmToM(c.width), 'h': mmToM(c.height), 'v': fmtNum(c.volumeM3, 1)})}\n'
      '${context.tr('doorPayload', {'w': mmToM(c.doorWidth), 'h': mmToM(c.doorHeight), 'p': fmtNum(c.payloadKg)})}';

  Widget _card(BuildContext context, String code, String title, String? details) {
    final on = _code == code;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: on ? AppColors.blue.withValues(alpha: 0.18) : AppColors.panel.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? AppColors.cyan : AppColors.border, width: on ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _select(code),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: on ? AppColors.cyan : AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (details != null) ...[
                      const SizedBox(height: 3),
                      Text(details, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customForm(BuildContext context) {
    Widget field(String k, String label) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: _c[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: context.tr(label)),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (_) {
              if (_v(k) == null) return context.tr('errPositive');
              if ((k == 'dw' && (_v('w') ?? 0) < (_v('dw') ?? 0)) || (k == 'dh' && (_v('h') ?? 0) < (_v('dh') ?? 0))) {
                return context.tr('errDoor');
              }
              return null;
            },
            onChanged: (_) => _emit(),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          field('l', 'insideLength'),
          Row(children: [
            Expanded(child: field('w', 'insideWidth')),
            const SizedBox(width: 8),
            Expanded(child: field('h', 'insideHeight')),
          ]),
          Row(children: [
            Expanded(child: field('dw', 'doorWidth')),
            const SizedBox(width: 8),
            Expanded(child: field('dh', 'doorHeight')),
          ]),
          field('p', 'payloadKg'),
        ],
      ),
    );
  }
}
