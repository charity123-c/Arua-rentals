import 'package:intl/intl.dart';

String formatUgx(int amount) => 'UGX ${NumberFormat('#,##0', 'en_US').format(amount)}';
