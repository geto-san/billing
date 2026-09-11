part of 'inventory_box_model.dart';

class InventoryBoxModelAdapter extends TypeAdapter<InventoryBoxModel> {
  @override
  final int typeId = 2;

  @override
  InventoryBoxModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryBoxModel(
      id: fields[0] as String,
      barcode: fields[1] as String,
      productName: fields[2] as String,
      initialStock: fields[3] as int,
      currentStock: fields[4] as int,
      defaultUnitPrice: (fields[5] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, InventoryBoxModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.barcode)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.initialStock)
      ..writeByte(4)
      ..write(obj.currentStock)
      ..writeByte(5)
      ..write(obj.defaultUnitPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryBoxModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
