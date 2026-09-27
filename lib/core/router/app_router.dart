import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/join_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/executor/tasks_screen.dart';
import '../../features/items/home_screen.dart';
import '../supabase/supabase_providers.dart';
import 'app_routes.dart';

/// حراسة مبدئية: بلا جلسة يُعاد المستخدم لتسجيل الدخول.
/// التوجيه حسب الدور (مدير/شريك → /home، منفذ → /tasks) يُضاف في المهمة 2.
String? authRedirect({required bool isSignedIn, required String location}) {
  if (!isSignedIn && !AppRoutes.public.contains(location)) {
    return AppRoutes.signIn;
  }
  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStatusProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.signIn,
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(
      isSignedIn: auth.isSignedIn,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.join,
        builder: (context, state) => const JoinScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.tasks,
        builder: (context, state) => const TasksScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
