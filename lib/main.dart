import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    debugPrint(
      'SUPABASE_URL / SUPABASE_ANON_KEY are empty. '
      'Pass them with --dart-define.',
    );
    runApp(const ConfigErrorApp());
    return;
  }

  await SupabaseConfig.initialize();
  runApp(
    ProviderScope(
      overrides: [
        authStatusProvider.overrideWithValue(
          SupabaseAuthStatus(Supabase.instance.client.auth),
        ),
      ],
      child: const HomeNeedsApp(),
    ),
  );
}
