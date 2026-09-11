import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/money_format.dart';
import '../../credit/data/models/credit_account_model.dart';
import '../data/models/sales_transaction_model.dart';

class StockSalesSummary {
  StockSalesSummary._();

  static String build({
    required String productName,
    required String boxId,
    required List<SalesTransactionModel> transactions,
    required List<CreditAccountModel> creditAccounts,
  }) {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final cash = transactions.where((t) => t.isCash).toList();
    final mtn = transactions.where((t) => t.isMtn).toList();
    final airtel = transactions.where((t) => t.isAirtel).toList();
    final mm = transactions.where((t) => t.isMobileMoney).toList();
    final credit = transactions.where((t) => t.isCredit).toList();

    double sum(List<SalesTransactionModel> list) =>
        list.fold(0.0, (p, t) => p + t.totalAmount);
    int units(List<SalesTransactionModel> list) =>
        list.fold(0, (p, t) => p + t.quantitySold);

    final buf = StringBuffer();
    buf.writeln('STOCK SALES SUMMARY');
    buf.writeln('Product: $productName');
    buf.writeln('Box: $boxId');
    buf.writeln('Printed: ${dateFmt.format(DateTime.now())}');
    buf.writeln('Unit price: ${MoneyFormat.format(AppConstants.defaultUnitPrice)}');
    buf.writeln('--------------------------------');
    buf.writeln('Units sold: ${units(transactions)}');
    buf.writeln('Total sales: ${MoneyFormat.format(sum(transactions))}');
    buf.writeln('');
    buf.writeln('CASH: ${units(cash)} units / ${MoneyFormat.format(sum(cash))}');
    buf.writeln('MOBILE MONEY: ${units(mm)} units / ${MoneyFormat.format(sum(mm))}');
    buf.writeln('  MTN: ${units(mtn)} / ${MoneyFormat.format(sum(mtn))}');
    buf.writeln('  Airtel: ${units(airtel)} / ${MoneyFormat.format(sum(airtel))}');
    buf.writeln('CREDIT: ${units(credit)} units / ${MoneyFormat.format(sum(credit))}');
    buf.writeln('--------------------------------');
    buf.writeln('TRANSACTIONS');
    if (transactions.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final t in transactions) {
        buf.writeln(
          '${dateFmt.format(t.timestamp)}  ${t.quantitySold}x ${t.productName}  '
          '${MoneyFormat.format(t.totalAmount)}  ${t.paymentLabel}',
        );
      }
    }
    buf.writeln('--------------------------------');
    buf.writeln('CREDIT ACCOUNTS CLEARED');
    if (creditAccounts.isEmpty) {
      buf.writeln('(none)');
    } else {
      for (final a in creditAccounts) {
        buf.writeln('${a.personName} owed ${MoneyFormat.format(a.amountOwed)}');
        for (final p in a.purchases) {
          buf.writeln(
            '  ${dateFmt.format(p.date)}  ${p.quantity}x ${p.productName}  '
            '${MoneyFormat.format(p.amount)}',
          );
        }
      }
    }
    buf.writeln('--------------------------------');
    buf.writeln('End of stock report');
    return buf.toString();
  }
}
