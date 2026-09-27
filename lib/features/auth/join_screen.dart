import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/placeholder_screen.dart';

class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PlaceholderScreen(
      title: l10n.joinTitle,
      children: [
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.signIn),
          child: Text(l10n.signInTitle),
        ),
      ],
    );
  }
}
