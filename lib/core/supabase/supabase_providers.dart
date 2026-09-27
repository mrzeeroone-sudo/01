import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// العميل لاستخدام طبقة repositories فقط؛ الشاشات لا تستدعيه مباشرة.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// حالة الدخول كما يحتاجها التوجيه: قيمة حالية + إشعار عند التغيّر.
abstract class AuthStatus implements Listenable {
  bool get isSignedIn;
}

class SupabaseAuthStatus extends ChangeNotifier implements AuthStatus {
  SupabaseAuthStatus(this._auth) {
    _auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final GoTrueClient _auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;
}

/// يُستبدل في main.dart بالتنفيذ الفعلي، وفي الاختبارات بتنفيذ وهمي.
final authStatusProvider = Provider<AuthStatus>(
  (ref) => throw UnimplementedError('authStatusProvider must be overridden'),
);
