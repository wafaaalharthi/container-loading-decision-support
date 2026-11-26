import 'package:flutter/material.dart';

import '../../data/shipment_repository.dart';
import '../../domain/containers.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/container_selector.dart';
import 'shipment_screen.dart';

class NewShipmentScreen extends StatefulWidget {
  const NewShipmentScreen({super.key});

  @override
  State<NewShipmentScreen> createState() => _NewShipmentScreenState();
}

class _NewShipmentScreenState extends State<NewShipmentScreen> {
  final _repo = ShipmentRepository();
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  ContainerDims? _container = containerPresets.first;
  bool _busy = false;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    final user = AppScope.read(context).user;
    if (user != null) {
      _repo.nextCode(user.id).then((c) {
        if (mounted && _code.text.isEmpty) _code.text = c;
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _codeError = null);
    if (!_form.currentState!.validate() || _container == null) return;
    final user = AppScope.read(context).user!;
    setState(() => _busy = true);
    if (await _repo.codeExists(user.id, _code.text.trim())) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeError = context.tr('errCodeUsed');
      });
      return;
    }
    final id = await _repo.create(user.id, _code.text, _name.text, _container!);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ShipmentScreen(shipmentId: id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('newShipment'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: context.tr('shipmentCode'), errorText: _codeError),
              validator: (v) => (v ?? '').trim().isEmpty ? context.tr('errRequired') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: context.tr('shipmentName')),
            ),
            SectionTitle(context.tr('chooseContainer')),
            ContainerSelector(
              initial: containerPresets.first,
              onChanged: (c) => setState(() => _container = c),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: context.tr('create'),
              icon: Icons.check,
              busy: _busy,
              onPressed: _container == null ? null : _create,
            ),
          ],
        ),
      ),
    );
  }
}
