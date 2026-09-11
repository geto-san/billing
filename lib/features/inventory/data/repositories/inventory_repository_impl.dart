import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../models/inventory_box_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  @override
  Future<Either<Failure, List<InventoryBoxModel>>> getBoxes() async {
    try {
      final box = HiveDatabase.inventoryBox;
      if (box.isEmpty) {
        await HiveDatabase.seedDefaultInventory(box);
      }
      return Right(box.values.toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryBoxModel>> getBoxByBarcode(String barcode) async {
    try {
      final box = HiveDatabase.inventoryBox;
      final cleanBarcode = barcode.trim();
      final inventoryBox = box.values.firstWhere(
        (b) => b.barcode.trim().toLowerCase() == cleanBarcode.toLowerCase(),
        orElse: () => throw Exception('Box with barcode "$barcode" not found'),
      );
      return Right(inventoryBox);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveBox(InventoryBoxModel boxModel) async {
    try {
      final box = HiveDatabase.inventoryBox;
      await box.put(boxModel.id, boxModel);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deductStock(String boxId, int quantity) async {
    try {
      final box = HiveDatabase.inventoryBox;
      final current = box.get(boxId);
      if (current == null) {
        return Left(CacheFailure('Box "$boxId" not found in inventory'));
      }
      final newStock = (current.currentStock - quantity).clamp(0, current.initialStock * 100);
      final updated = current.copyWith(currentStock: newStock);
      await box.put(boxId, updated);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> restoreStock(String boxId, int quantity) async {
    try {
      final box = HiveDatabase.inventoryBox;
      final current = box.get(boxId);
      if (current == null) {
        return Left(CacheFailure('Box "$boxId" not found in inventory'));
      }
      final newStock = current.currentStock + quantity;
      final updated = current.copyWith(currentStock: newStock);
      await box.put(boxId, updated);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetToDefaults() async {
    try {
      final box = HiveDatabase.inventoryBox;
      await box.clear();
      await HiveDatabase.seedDefaultInventory(box);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
