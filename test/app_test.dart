import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_needs/app.dart';
import 'package:home_needs/core/router/app_router.dart';
import 'package:home_needs/core/router/app_routes.dart';
import 'package:home_needs/core/supabase/supabase_providers.dart';
import 'package:home_needs/core/theme/app_theme.dart';
import 'package:home_needs/core/theme/number_format.dart';
import 'package:home_needs/data/models/item_status.dart';

class _FakeAuth extends ChangeNotifier implements AuthStatus {
  @override
  bool isSignedIn = false;
}

Widget _app() => ProviderScope(
  overrides: [
    authStatusProvider.overrideWithValue(_FakeAuth()),
    appThemeProvider.overrideWithValue(buildAppTheme(useGoogleFonts: false)),
  ],
  child: const HomeNeedsApp(),
);

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));

Future<void> _pickLanguage(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(const Key('language-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('language-$code')).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts in Arabic RTL and switching language flips direction', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(_direction(tester), TextDirection.rtl);

    await _pickLanguage(tester, 'en');
    expect(find.text('Sign in'), findsWidgets);
    expect(_direction(tester), TextDirection.ltr);

    await _pickLanguage(tester, 'ur');
    expect(find.text('سائن ان'), findsWidgets);
    expect(_direction(tester), TextDirection.rtl);
  });

  test('protected routes redirect to sign-in without a session', () {
    expect(
      authRedirect(isSignedIn: false, location: AppRoutes.home),
      AppRoutes.signIn,
    );
    expect(
      authRedirect(isSignedIn: false, location: AppRoutes.tasks),
      AppRoutes.signIn,
    );
    expect(authRedirect(isSignedIn: false, location: AppRoutes.join), isNull);
    expect(authRedirect(isSignedIn: true, location: AppRoutes.home), isNull);
  });

  test('amounts use Western digits', () {
    expect(formatAmount(1234.5), '1,234.5');
    expect(formatAmount(760), '760');
  });

  test('item status maps to database values', () {
    expect(ItemStatus.fromDb('new'), ItemStatus.newItem);
    expect(ItemStatus.values.map((s) => s.dbValue), [
      'new',
      'assigned',
      'bought',
      'deferred',
      'rejected',
      'cancelled',
    ]);
    expect(() => ItemStatus.fromDb('x'), throwsArgumentError);
  });
}
