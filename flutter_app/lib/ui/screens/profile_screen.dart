import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'shell.dart' show shellTab;

/// Edit name and email, change password, sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _infoForm = GlobalKey<FormState>();
  final _pwForm = GlobalKey<FormState>();
  late final _name = TextEditingController(text: AppScope.read(context).user?.name ?? '');
  late final _email = TextEditingController(text: AppScope.read(context).user?.email ?? '');
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _next2 = TextEditingController();
  bool _busyInfo = false, _busyPw = false, _hide = true;
  String? _emailError, _pwError;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    for (final c in [_name, _email, _current, _next, _next2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveInfo() async {
    setState(() => _emailError = null);
    if (!_infoForm.currentState!.validate()) return;
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyInfo = true);
    try {
      await app.updateProfile(_name.text, _email.text);
      messenger.showSnackBar(SnackBar(content: Text(app.t('profileSaved'))));
    } on AuthException {
      if (mounted) setState(() => _emailError = app.t('errExists'));
    } finally {
      if (mounted) setState(() => _busyInfo = false);
    }
  }

  Future<void> _changePw() async {
    setState(() => _pwError = null);
    if (!_pwForm.currentState!.validate()) return;
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyPw = true);
    try {
      await app.changePassword(_current.text, _next.text);
      _current.clear();
      _next.clear();
      _next2.clear();
      messenger.showSnackBar(SnackBar(content: Text(app.t('passwordChanged'))));
    } on AuthException {
      if (mounted) setState(() => _pwError = app.t('errCurrentPw'));
    } finally {
      if (mounted) setState(() => _busyPw = false);
    }
  }

  Future<void> _signOut() async {
    final nav = Navigator.of(context);
    final app = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        content: Text(ctx.tr('signOutConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('signOut'), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    shellTab.value = 0;
    nav.popUntil((r) => r.isFirst);
    await app.signOut();
  }

  InputDecoration _dec(String key, {String? error, Widget? suffix}) =>
      InputDecoration(labelText: context.tr(key), errorText: error, suffixIcon: suffix);

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _hide = !_hide),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _infoForm,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('account'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: _dec('fullName'),
                    validator: (v) => (v ?? '').trim().isEmpty ? context.tr('errName') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('email', error: _emailError),
                    validator: (v) => _emailRe.hasMatch((v ?? '').trim()) ? null : context.tr('errEmail'),
                  ),
                  const SizedBox(height: 14),
                  GradientButton(label: context.tr('saveChanges'), icon: Icons.check, busy: _busyInfo, onPressed: _saveInfo),
                ],
              ),
            ),
          ),
          Form(
            key: _pwForm,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('changePassword'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _current,
                    obscureText: _hide,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('currentPassword', error: _pwError, suffix: eye),
                    validator: (v) => (v ?? '').isEmpty ? context.tr('errRequired') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _next,
                    obscureText: _hide,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('newPassword'),
                    validator: (v) => (v ?? '').length < 6 ? context.tr('errPw') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _next2,
                    obscureText: _hide,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('confirmPassword'),
                    validator: (v) => v != _next.text ? context.tr('errMatch') : null,
                  ),
                  const SizedBox(height: 14),
                  OutlineAppButton(label: context.tr('changePassword'), icon: Icons.lock_reset, onPressed: _busyPw ? null : _changePw),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          OutlineAppButton(label: context.tr('signOut'), icon: Icons.logout, onPressed: _signOut),
        ],
      ),
    );
  }
}
