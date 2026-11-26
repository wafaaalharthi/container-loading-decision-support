import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/container_scene.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _open(BuildContext context, AuthMode mode) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthScreen(mode: mode)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                  child: Column(
                    children: [
                      const Align(alignment: AlignmentDirectional.centerEnd, child: LangToggle()),
                      const SizedBox(height: 18),
                      Text(context.tr('uj'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      ShaderMask(
                        shaderCallback: (r) => const LinearGradient(
                          colors: [AppColors.text, AppColors.cyan],
                        ).createShader(r),
                        child: const Text(
                          'Senior Project 1',
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const RotatingContainer(height: 300),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('welcomeWhat'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15.5, height: 1.65, color: AppColors.text),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: context.tr('signIn'),
                          icon: Icons.person_outline,
                          onPressed: () => _open(context, AuthMode.signIn),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlineAppButton(
                          label: context.tr('createAccount'),
                          icon: Icons.person_add_alt,
                          onPressed: () => _open(context, AuthMode.signUp),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
