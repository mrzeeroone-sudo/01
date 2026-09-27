import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// اللغات المدعومة في النسخة الأولى؛ العربية الافتراضية.
const supportedAppLocales = [Locale('ar'), Locale('en'), Locale('ur')];

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => supportedAppLocales.first;

  void set(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
