import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const _seed = Color(0xFF3F6B5C);

ThemeData buildAppTheme({bool useGoogleFonts = true}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ),
  );
  return base.copyWith(
    // Cairo يدعم العربية والأردية واللاتينية بخط واحد.
    textTheme: useGoogleFonts
        ? GoogleFonts.cairoTextTheme(base.textTheme)
        : null,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    ),
  );
}

/// يُستبدل في الاختبارات بثيم لا يحمّل خطوطاً من الشبكة.
final appThemeProvider = Provider<ThemeData>((ref) => buildAppTheme());
