import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class MoneyFormat {
  static final NumberFormat _number = NumberFormat('#,##0', 'en_US');

  static String format(num amount) {
    return '${AppConstants.currencySymbol} ${_number.format(amount.round())}';
  }
}
