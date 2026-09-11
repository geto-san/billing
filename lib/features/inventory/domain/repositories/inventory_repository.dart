import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../data/models/inventory_box_model.dart';

abstract class InventoryRepository {
  Future<Either<Failure, List<InventoryBoxModel>>> getBoxes();
  Future<Either<Failure, InventoryBoxModel>> getBoxByBarcode(String barcode);
  Future<Either<Failure, void>> saveBox(InventoryBoxModel box);
  Future<Either<Failure, void>> deductStock(String boxId, int quantity);
  Future<Either<Failure, void>> restoreStock(String boxId, int quantity);
  Future<Either<Failure, void>> resetToDefaults();
}
