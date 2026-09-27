import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../locale/locale_controller.dart';

/// زر في شريط العنوان يعرض كل لغة باسمها بلغتها.
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    return PopupMenuButton<Locale>(
      key: const Key('language-menu'),
      icon: const Icon(Icons.language),
      tooltip: AppLocalizations.of(context).changeLanguage,
      initialValue: current,
      onSelected: ref.read(localeProvider.notifier).set,
      itemBuilder: (context) => [
        for (final locale in supportedAppLocales)
          PopupMenuItem(
            key: Key('language-${locale.languageCode}'),
            value: locale,
            child: Text(lookupAppLocalizations(locale).languageName),
          ),
      ],
    );
  }
}
