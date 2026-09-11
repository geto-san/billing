import 'package:equatable/equatable.dart';
import '../../data/models/inventory_box_model.dart';

enum InventoryStatus { initial, loading, loaded, error }

class InventoryState extends Equatable {
  final InventoryStatus status;
  final List<InventoryBoxModel> boxes;
  final String? errorMessage;
  final String? successMessage;

  const InventoryState({
    this.status = InventoryStatus.initial,
    this.boxes = const [],
    this.errorMessage,
    this.successMessage,
  });

  InventoryBoxModel? findBoxByBarcode(String barcode) {
    final clean = barcode.trim().toLowerCase();
    return boxes.cast<InventoryBoxModel?>().firstWhere(
          (b) => b?.barcode.trim().toLowerCase() == clean,
          orElse: () => null,
        );
  }

  InventoryBoxModel? findBoxById(String id) {
    return boxes.cast<InventoryBoxModel?>().firstWhere(
          (b) => b?.id == id,
          orElse: () => null,
        );
  }

  InventoryState copyWith({
    InventoryStatus? status,
    List<InventoryBoxModel>? boxes,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return InventoryState(
      status: status ?? this.status,
      boxes: boxes ?? this.boxes,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [status, boxes, errorMessage, successMessage];
}
