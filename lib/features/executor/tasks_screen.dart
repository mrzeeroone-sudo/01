import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/placeholder_screen.dart';

/// واجهة المنفذ. تُبنى البطاقات والإغلاق في المهمة 5.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.tasksTitle,
      children: [Text(l10n.emptyList)],
    );
  }
}
