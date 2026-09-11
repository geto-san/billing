part of 'sales_transaction_model.dart';

class SalesTransactionModelAdapter extends TypeAdapter<SalesTransactionModel> {
  @override
  final int typeId = 3;

  @override
  SalesTransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final rawTs = fields[1];
    return SalesTransactionModel(
      id: fields[0] as String,
      timestamp: rawTs is DateTime ? rawTs : DateTime.parse(rawTs as String),
      boxId: fields[2] as String,
      productName: fields[3] as String,
      quantitySold: fields[4] as int,
      unitPrice: (fields[5] as num).toDouble(),
      totalAmount: (fields[6] as num).toDouble(),
      paymentMethod: (fields[7] as String?) ?? 'cash',
      mobileNetwork: fields[8] as String?,
      creditAccountId: fields[9] as String?,
      creditPersonName: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SalesTransactionModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp.toIso8601String())
      ..writeByte(2)
      ..write(obj.boxId)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(4)
      ..write(obj.quantitySold)
      ..writeByte(5)
      ..write(obj.unitPrice)
      ..writeByte(6)
      ..write(obj.totalAmount)
      ..writeByte(7)
      ..write(obj.paymentMethod)
      ..writeByte(8)
      ..write(obj.mobileNetwork)
      ..writeByte(9)
      ..write(obj.creditAccountId)
      ..writeByte(10)
      ..write(obj.creditPersonName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesTransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
