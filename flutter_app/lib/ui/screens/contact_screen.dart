import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

/// Contact details (demo values, not real).
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const _items = [
    (Icons.call_outlined, 'contactCompany', '+966 12 000 0000'),
    (Icons.support_agent, 'contactSupport', '800 000 0000'),
    (Icons.mail_outline, 'contactEmail', 'support@seniorproject1.example'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('contact'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (icon, key, value) in _items)
            AppCard(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(value, textDirection: TextDirection.ltr)));
              },
              child: Row(
                children: [
                  Icon(icon, color: AppColors.cyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr(key), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(value,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                  ),
                  const Icon(Icons.copy, size: 18, color: AppColors.muted),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Text(context.tr('contactHours'), style: const TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(context.tr('contactDemo'), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
