part of 'credit_account_model.dart';

class CreditPurchaseModelAdapter extends TypeAdapter<CreditPurchaseModel> {
  @override
  final int typeId = 4;

  @override
  CreditPurchaseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CreditPurchaseModel(
      productName: fields[0] as String,
      date: fields[1] is DateTime
          ? fields[1] as DateTime
          : DateTime.parse(fields[1] as String),
      quantity: fields[2] as int,
      amount: (fields[3] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, CreditPurchaseModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.productName)
      ..writeByte(1)
      ..write(obj.date.toIso8601String())
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.amount);
  }
}

class CreditAccountModelAdapter extends TypeAdapter<CreditAccountModel> {
  @override
  final int typeId = 5;

  @override
  CreditAccountModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CreditAccountModel(
      id: fields[0] as String,
      personName: fields[1] as String,
      openedAt: fields[2] is DateTime
          ? fields[2] as DateTime
          : DateTime.parse(fields[2] as String),
      amountOwed: (fields[3] as num).toDouble(),
      purchases: (fields[4] as List?)?.cast<CreditPurchaseModel>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, CreditAccountModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.personName)
      ..writeByte(2)
      ..write(obj.openedAt.toIso8601String())
      ..writeByte(3)
      ..write(obj.amountOwed)
      ..writeByte(4)
      ..write(obj.purchases);
  }
}
