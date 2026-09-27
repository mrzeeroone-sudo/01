import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'language_menu_button.dart';

/// هيكل مؤقت للشاشات حتى تُبنى في مهامها.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.children = const [],
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageMenuButton()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.comingSoon,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            for (final child in children) ...[
              child,
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
