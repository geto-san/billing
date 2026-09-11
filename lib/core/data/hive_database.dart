import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';
import '../utils/backup_service.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/inventory/data/models/inventory_box_model.dart';
import '../../features/sales/data/models/sales_transaction_model.dart';
import '../../features/credit/data/models/credit_account_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String inventoryBoxName = 'inventory';
  static const String salesTransactionsBoxName = 'sales_transactions';
  static const String creditAccountsBoxName = 'credit_accounts';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(InventoryBoxModelAdapter());
    Hive.registerAdapter(SalesTransactionModelAdapter());
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(CreditPurchaseModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(CreditAccountModelAdapter());
    }

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    final invBox =
        await Hive.openBox<InventoryBoxModel>(inventoryBoxName);
    await Hive.openBox<SalesTransactionModel>(salesTransactionsBoxName);
    await Hive.openBox<CreditAccountModel>(creditAccountsBoxName);
    await BackupService.ensurePermissions();

    for (final key in invBox.keys) {
      final current = invBox.get(key);
      if (current != null &&
          current.defaultUnitPrice != AppConstants.defaultUnitPrice) {
        await invBox.put(
          key,
          current.copyWith(defaultUnitPrice: AppConstants.defaultUnitPrice),
        );
      }
    }

    // Initial setup of 3 default inventory boxes if inventory is empty
    if (invBox.isEmpty) {
      await seedDefaultInventory(invBox);
    }
  }

  static Future<void> seedDefaultInventory(
      Box<InventoryBoxModel> box) async {
    final defaultBoxes = [
      const InventoryBoxModel(
        id: 'box_1',
        barcode: 'BOX-CHOC-001',
        productName: 'Chocolates',
        initialStock: 100,
        currentStock: 100,
        defaultUnitPrice: AppConstants.defaultUnitPrice,
      ),
      const InventoryBoxModel(
        id: 'box_2',
        barcode: 'BOX-COOK-002',
        productName: 'Cookies',
        initialStock: 100,
        currentStock: 100,
        defaultUnitPrice: AppConstants.defaultUnitPrice,
      ),
      const InventoryBoxModel(
        id: 'box_3',
        barcode: 'BOX-BISC-003',
        productName: 'Biscuits',
        initialStock: 100,
        currentStock: 100,
        defaultUnitPrice: AppConstants.defaultUnitPrice,
      ),
    ];

    for (final b in defaultBoxes) {
      await box.put(b.id, b);
    }
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box<InventoryBoxModel> get inventoryBox =>
      Hive.box<InventoryBoxModel>(inventoryBoxName);
  static Box<SalesTransactionModel> get salesTransactionsBox =>
      Hive.box<SalesTransactionModel>(salesTransactionsBoxName);
  static Box<CreditAccountModel> get creditAccountsBox =>
      Hive.box<CreditAccountModel>(creditAccountsBoxName);
}

