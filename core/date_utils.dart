import 'package:intl/intl.dart';

class DateHelpers {
  static final _fmt = DateFormat('yyyyMMdd');
  static String todayKey() => _fmt.format(DateTime.now());
  static String humanToday() => DateFormat('MMMM d, yyyy').format(DateTime.now());
}
