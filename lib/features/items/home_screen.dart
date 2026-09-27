import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/number_format.dart';
import '../../core/widgets/placeholder_screen.dart';
import '../../core/widgets/status_label.dart';
import '../../data/models/item_status.dart';

/// واجهة البيت (مدير/شريك). تُبنى القائمة الفعلية في المهمة 3.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.homeTitle,
      children: [
        Text(l10n.expectedTotal(formatAmount(0))),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in ItemStatus.values)
              Chip(label: Text(statusLabel(l10n, status))),
          ],
        ),
      ],
    );
  }
}
