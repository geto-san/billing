import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'inventory_box_model.g.dart';

@HiveType(typeId: 2)
class InventoryBoxModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String barcode;

  @HiveField(2)
  final String productName;

  @HiveField(3)
  final int initialStock;

  @HiveField(4)
  final int currentStock;

  @HiveField(5)
  final double defaultUnitPrice;

  const InventoryBoxModel({
    required this.id,
    required this.barcode,
    required this.productName,
    required this.initialStock,
    required this.currentStock,
    required this.defaultUnitPrice,
  });

  InventoryBoxModel copyWith({
    String? id,
    String? barcode,
    String? productName,
    int? initialStock,
    int? currentStock,
    double? defaultUnitPrice,
  }) {
    return InventoryBoxModel(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      initialStock: initialStock ?? this.initialStock,
      currentStock: currentStock ?? this.currentStock,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
    );
  }

  @override
  List<Object?> get props => [
        id,
        barcode,
        productName,
        initialStock,
        currentStock,
        defaultUnitPrice,
      ];
}
