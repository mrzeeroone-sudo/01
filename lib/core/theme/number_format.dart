import 'package:intl/intl.dart';

// أرقام غربية (0-9) في كل الواجهات بغض النظر عن لغة الواجهة.
final _amountFormat = NumberFormat('#,##0.##', 'en');

String formatAmount(num value) => _amountFormat.format(value);
