import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'credit_account_model.g.dart';

@HiveType(typeId: 4)
class CreditPurchaseModel extends Equatable {
  @HiveField(0)
  final String productName;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int quantity;

  @HiveField(3)
  final double amount;

  const CreditPurchaseModel({
    required this.productName,
    required this.date,
    required this.quantity,
    required this.amount,
  });

  @override
  List<Object?> get props => [productName, date, quantity, amount];
}

@HiveType(typeId: 5)
class CreditAccountModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String personName;

  @HiveField(2)
  final DateTime openedAt;

  @HiveField(3)
  final double amountOwed;

  @HiveField(4)
  final List<CreditPurchaseModel> purchases;

  const CreditAccountModel({
    required this.id,
    required this.personName,
    required this.openedAt,
    required this.amountOwed,
    this.purchases = const [],
  });

  CreditAccountModel copyWith({
    String? id,
    String? personName,
    DateTime? openedAt,
    double? amountOwed,
    List<CreditPurchaseModel>? purchases,
  }) {
    return CreditAccountModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      openedAt: openedAt ?? this.openedAt,
      amountOwed: amountOwed ?? this.amountOwed,
      purchases: purchases ?? this.purchases,
    );
  }

  @override
  List<Object?> get props => [id, personName, openedAt, amountOwed, purchases];
}
