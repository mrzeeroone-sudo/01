import 'package:supabase_flutter/supabase_flutter.dart';

/// مفاتيح Supabase تُمرَّر وقت البناء عبر --dart-define ولا تُكتب في الكود.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  // مفتاح anon يُمرَّر كـ publishableKey (الاسم الجديد في supabase_flutter).
  static Future<void> initialize() =>
      Supabase.initialize(url: url, publishableKey: anonKey);
}
