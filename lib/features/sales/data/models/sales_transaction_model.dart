import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'sales_transaction_model.g.dart';

@HiveType(typeId: 3)
class SalesTransactionModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String boxId;

  @HiveField(3)
  final String productName;

  @HiveField(4)
  final int quantitySold;

  @HiveField(5)
  final double unitPrice;

  @HiveField(6)
  final double totalAmount;

  /// cash | mobile_money | credit
  @HiveField(7)
  final String paymentMethod;

  /// mtn | airtel
  @HiveField(8)
  final String? mobileNetwork;

  @HiveField(9)
  final String? creditAccountId;

  @HiveField(10)
  final String? creditPersonName;

  const SalesTransactionModel({
    required this.id,
    required this.timestamp,
    required this.boxId,
    required this.productName,
    required this.quantitySold,
    required this.unitPrice,
    required this.totalAmount,
    this.paymentMethod = 'cash',
    this.mobileNetwork,
    this.creditAccountId,
    this.creditPersonName,
  });

  bool get isCash => paymentMethod == 'cash';
  bool get isMobileMoney => paymentMethod == 'mobile_money';
  bool get isCredit => paymentMethod == 'credit';
  bool get isCreditSettlement => paymentMethod == 'credit_settled';
  bool get isMtn => isMobileMoney && mobileNetwork == 'mtn';
  bool get isAirtel => isMobileMoney && mobileNetwork == 'airtel';
  bool get isSettlementMtn => isCreditSettlement && mobileNetwork == 'mtn';
  bool get isSettlementAirtel => isCreditSettlement && mobileNetwork == 'airtel';

  String get paymentLabel {
    if (isCash) return 'Cash';
    if (isMtn) return 'Mobile Money (MTN)';
    if (isAirtel) return 'Mobile Money (Airtel)';
    if (isMobileMoney) return 'Mobile Money';
    if (isCredit) {
      final name = creditPersonName;
      return name == null || name.isEmpty ? 'Credit' : 'Credit ($name)';
    }
    if (isCreditSettlement) {
      final name = creditPersonName;
      final base = name == null || name.isEmpty ? 'Credit Settled' : 'Credit Settled ($name)';
      if (mobileNetwork == 'mtn') return '$base — MTN';
      if (mobileNetwork == 'airtel') return '$base — Airtel';
      return base;
    }
    return paymentMethod;
  }

  @override
  List<Object?> get props => [
        id,
        timestamp,
        boxId,
        productName,
        quantitySold,
        unitPrice,
        totalAmount,
        paymentMethod,
        mobileNetwork,
        creditAccountId,
        creditPersonName,
      ];
}
