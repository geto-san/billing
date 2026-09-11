import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/inventory_repository.dart';
import 'inventory_event.dart';
import 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository repository;

  InventoryBloc({required this.repository}) : super(const InventoryState()) {
    on<LoadInventoryEvent>(_onLoadInventory);
    on<UpdateBoxEvent>(_onUpdateBox);
    on<RestockBoxEvent>(_onRestockBox);
    on<ResetInventoryToDefaultsEvent>(_onResetDefaults);
    on<DeductStockEvent>(_onDeductStock);
  }

  Future<void> _onLoadInventory(
      LoadInventoryEvent event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading, clearMessages: true));
    final result = await repository.getBoxes();
    result.fold(
      (failure) => emit(state.copyWith(
        status: InventoryStatus.error,
        errorMessage: failure.message,
      )),
      (boxes) => emit(state.copyWith(
        status: InventoryStatus.loaded,
        boxes: boxes,
        clearMessages: true,
      )),
    );
  }

  Future<void> _onUpdateBox(
      UpdateBoxEvent event, Emitter<InventoryState> emit) async {
    final result = await repository.saveBox(event.box);
    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: 'Failed to update box: ${failure.message}',
      )),
      (_) {
        final updatedBoxes = state.boxes.map((b) {
          return b.id == event.box.id ? event.box : b;
        }).toList();
        emit(state.copyWith(
          boxes: updatedBoxes,
          successMessage: 'Box "${event.box.productName}" updated successfully',
        ));
      },
    );
  }

  Future<void> _onRestockBox(
      RestockBoxEvent event, Emitter<InventoryState> emit) async {
    final result = await repository.restoreStock(event.boxId, event.additionalStock);
    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: 'Failed to restock: ${failure.message}',
      )),
      (_) async {
        final boxesResult = await repository.getBoxes();
        boxesResult.fold(
          (failure) => emit(state.copyWith(errorMessage: failure.message)),
          (boxes) => emit(state.copyWith(
            boxes: boxes,
            successMessage: 'Restocked +${event.additionalStock} units successfully',
          )),
        );
      },
    );
  }

  Future<void> _onResetDefaults(
      ResetInventoryToDefaultsEvent event, Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: InventoryStatus.loading));
    final result = await repository.resetToDefaults();
    result.fold(
      (failure) => emit(state.copyWith(
        status: InventoryStatus.error,
        errorMessage: failure.message,
      )),
      (_) async {
        final boxesResult = await repository.getBoxes();
        boxesResult.fold(
          (failure) => emit(state.copyWith(errorMessage: failure.message)),
          (boxes) => emit(state.copyWith(
            status: InventoryStatus.loaded,
            boxes: boxes,
            successMessage: 'Reset to 3 default inventory boxes',
          )),
        );
      },
    );
  }

  Future<void> _onDeductStock(
      DeductStockEvent event, Emitter<InventoryState> emit) async {
    final result = await repository.deductStock(event.boxId, event.quantity);
    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: 'Failed to deduct stock: ${failure.message}',
      )),
      (_) {
        final updatedBoxes = state.boxes.map((b) {
          if (b.id == event.boxId) {
            final newStock = (b.currentStock - event.quantity).clamp(0, 999999);
            return b.copyWith(currentStock: newStock);
          }
          return b;
        }).toList();
        emit(state.copyWith(boxes: updatedBoxes));
      },
    );
  }
}
