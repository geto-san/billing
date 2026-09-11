import 'package:equatable/equatable.dart';
import '../../data/models/inventory_box_model.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadInventoryEvent extends InventoryEvent {}

class UpdateBoxEvent extends InventoryEvent {
  final InventoryBoxModel box;
  const UpdateBoxEvent(this.box);

  @override
  List<Object?> get props => [box];
}

class RestockBoxEvent extends InventoryEvent {
  final String boxId;
  final int additionalStock;
  const RestockBoxEvent({required this.boxId, required this.additionalStock});

  @override
  List<Object?> get props => [boxId, additionalStock];
}

class ResetInventoryToDefaultsEvent extends InventoryEvent {}

class DeductStockEvent extends InventoryEvent {
  final String boxId;
  final int quantity;
  const DeductStockEvent({required this.boxId, required this.quantity});

  @override
  List<Object?> get props => [boxId, quantity];
}
