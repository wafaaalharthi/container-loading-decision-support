import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  final AuthMode mode;
  const AuthScreen({super.key, required this.mode});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  bool _hidePw = true;
  String? _error;

  bool get _signUp => widget.mode == AuthMode.signUp;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final app = context.app;
    try {
      if (_signUp) {
        await app.signUp(_name.text, _email.text, _pw.text);
      } else {
        await app.signIn(_email.text, _pw.text);
      }
      // Back to the root; it now shows the main shell
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = context.tr(e.error == AuthError.exists ? 'errExists' : 'errLogin'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(_signUp ? 'createAccount' : 'signIn');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [LangToggle(), SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.cyan, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(context.tr('authNote'),
                          style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_signUp) ...[
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: context.tr('fullName')),
                  validator: (v) => (v ?? '').trim().isEmpty ? context.tr('errName') : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: context.tr('email')),
                validator: (v) => _emailRe.hasMatch((v ?? '').trim()) ? null : context.tr('errEmail'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pw,
                obscureText: _hidePw,
                textDirection: TextDirection.ltr,
                textInputAction: _signUp ? TextInputAction.next : TextInputAction.done,
                onFieldSubmitted: _signUp ? null : (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.tr('password'),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePw ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hidePw = !_hidePw),
                  ),
                ),
                validator: (v) => (v ?? '').length < 6 ? context.tr('errPw') : null,
              ),
              if (_signUp) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pw2,
                  obscureText: _hidePw,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(labelText: context.tr('confirmPassword')),
                  validator: (v) => v != _pw.text ? context.tr('errMatch') : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 22),
              GradientButton(label: title, busy: _busy, onPressed: _submit),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (_) => AuthScreen(mode: _signUp ? AuthMode.signIn : AuthMode.signUp),
                        )),
                child: Text(context.tr(_signUp ? 'haveAccount' : 'noAccount')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
