import 'package:container_loading/container_loading.dart' show algorithms;
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'contact_screen.dart';
import 'profile_screen.dart';
import 'records_screens.dart';
import 'shell.dart' show shellTab;

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
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
    if (ok == true && context.mounted) {
      shellTab.value = 0;
      await context.app.signOut();
    }
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final user = app.user;
    final since = user == null ? '' : fmtDate(user.createdAt);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Account
        AppCard(
          onTap: () => _open(context, const ProfileScreen()),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.blue.withValues(alpha: 0.3),
                child: Text(
                  (user?.name.isNotEmpty ?? false) ? user!.name.characters.first.toUpperCase() : '?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.cyan),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(user?.email ?? '',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    Text(context.tr('memberSince', {'date': since}),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        SectionTitle(context.tr('language')),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            children: [
              _LangOption(code: 'ar', label: context.tr('arabic')),
              _LangOption(code: 'en', label: context.tr('english')),
            ],
          ),
        ),

        SectionTitle(context.tr('records')),
        _RowTile(icon: Icons.history, label: context.tr('opsRecords'), onTap: () => _open(context, const OpsRecordsScreen())),
        _RowTile(
          icon: Icons.description_outlined,
          label: context.tr('reportRecords'),
          onTap: () => _open(context, const ReportsRecordsScreen()),
        ),

        SectionTitle(context.tr('contact')),
        _RowTile(
          icon: Icons.support_agent,
          label: context.tr('contact'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
        ),

        SectionTitle(context.tr('about')),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Senior Project 1 · v1.0.0',
                  textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(context.tr('uj'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              Text(context.tr('engineInfo', {'n': algorithms.length}),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 6),
        OutlineAppButton(
          label: context.tr('signOut'),
          icon: Icons.logout,
          onPressed: () => _confirmSignOut(context),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RowTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Icon(isRtl ? Icons.chevron_left : Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String code;
  final String label;
  const _LangOption({required this.code, required this.label});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final on = app.lang == code;
    return ListTile(
      onTap: () => app.setLang(code),
      title: Text(label),
      trailing: Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: on ? AppColors.cyan : AppColors.muted),
    );
  }
}
