import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/backup_service.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../credit/presentation/bloc/credit_bloc.dart';
import '../../../sales/domain/stock_sales_summary.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_event.dart';
import '../../data/models/inventory_box_model.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../bloc/inventory_state.dart';

class InventoryBoxesPage extends StatelessWidget {
  const InventoryBoxesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Boxes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'View Barcodes',
            onPressed: () => context.push('/inventory/barcodes'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset') {
                _confirmResetDefaults(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reset to 3 Default Boxes'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == InventoryStatus.loading && state.boxes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.boxes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No inventory boxes found',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Setup 3 default boxes to get started.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Initialize 3 Default Boxes'),
                    onPressed: () => context
                        .read<InventoryBloc>()
                        .add(ResetInventoryToDefaultsEvent()),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: state.boxes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final box = state.boxes[index];
              return _InventoryBoxCard(box: box);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditBoxDialog(context, null),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_box),
        label: const Text('New Box'),
      ),
    );
  }

  void _confirmResetDefaults(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Inventory Boxes?'),
        content: const Text(
            'This will restore Box 1 (Chocolates), Box 2 (Cookies), and Box 3 (Biscuits) with initial 100 units stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<InventoryBloc>()
                  .add(ResetInventoryToDefaultsEvent());
            },
            child: const Text('Reset Defaults'),
          ),
        ],
      ),
    );
  }

  static void _showAddOrEditBoxDialog(
      BuildContext context, InventoryBoxModel? existingBox) {
    final isEditing = existingBox != null;
    final formKey = GlobalKey<FormState>();

    String id = existingBox?.id ?? 'box_${DateTime.now().millisecondsSinceEpoch}';
    String barcode = existingBox?.barcode ?? '';
    String productName = existingBox?.productName ?? '';
    int initialStock = existingBox?.initialStock ?? 100;
    int currentStock = existingBox?.currentStock ?? 100;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Box Details' : 'Add Inventory Box'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: productName,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g. Chocolates',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                  onSaved: (val) => productName = val!.trim(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: barcode,
                  decoration: const InputDecoration(
                    labelText: 'Box / Barcode ID',
                    hintText: 'e.g. BOX-CHOC-001',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                  onSaved: (val) => barcode = val!.trim(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: initialStock.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Initial Stock Quantity',
                  ),
                  validator: (val) {
                    final n = int.tryParse(val ?? '');
                    return n == null || n < 0 ? 'Enter valid number' : null;
                  },
                  onSaved: (val) => initialStock = int.parse(val!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: currentStock.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Current Stock Quantity',
                  ),
                  validator: (val) {
                    final n = int.tryParse(val ?? '');
                    return n == null || n < 0 ? 'Enter valid number' : null;
                  },
                  onSaved: (val) => currentStock = int.parse(val!),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unit price is ${MoneyFormat.format(AppConstants.defaultUnitPrice)} for every product.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState!.save();
                final updatedBox = InventoryBoxModel(
                  id: id,
                  barcode: barcode,
                  productName: productName,
                  initialStock: initialStock,
                  currentStock: currentStock,
                  defaultUnitPrice: AppConstants.defaultUnitPrice,
                );
                context.read<InventoryBloc>().add(UpdateBoxEvent(updatedBox));
                Navigator.pop(ctx);
              }
            },
            child: Text(isEditing ? 'Save Changes' : 'Create Box'),
          ),
        ],
      ),
    );
  }
}

class _InventoryBoxCard extends StatelessWidget {
  final InventoryBoxModel box;

  const _InventoryBoxCard({required this.box});

  @override
  Widget build(BuildContext context) {
    final stockPercent = box.initialStock > 0
        ? (box.currentStock / box.initialStock).clamp(0.0, 1.0)
        : 0.0;

    Color progressColor;
    Color badgeColor;
    String statusText;

    if (box.currentStock <= 0) {
      progressColor = Colors.red;
      badgeColor = Colors.red[50]!;
      statusText = 'OUT OF STOCK';
    } else if (box.currentStock < (box.initialStock * 0.25)) {
      progressColor = Colors.orange;
      badgeColor = Colors.orange[50]!;
      statusText = 'LOW STOCK';
    } else {
      progressColor = Colors.green;
      badgeColor = Colors.green[50]!;
      statusText = 'HEALTHY';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Name and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      box.productName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Box ID: ${box.id}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: progressColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barcode & Price Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      box.barcode,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${MoneyFormat.format(box.defaultUnitPrice)} / unit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stock Bar and Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Stock',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${box.currentStock}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${box.initialStock} units',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stockPercent,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 8),

          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('End stock'),
                onPressed: () => _endStockAndPrint(context, box),
              ),
              TextButton.icon(
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('QR Code'),
                onPressed: () => _showBarcodeDialog(context, box),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Restock'),
                onPressed: () => _showRestockDialog(context, box),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.primaryColor,
                tooltip: 'Edit Box',
                onPressed: () =>
                    InventoryBoxesPage._showAddOrEditBoxDialog(context, box),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _endStockAndPrint(
      BuildContext context, InventoryBoxModel box) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End stock for ${box.productName}?'),
        content: const Text(
          'This prints a sales summary for this box and saves it in the backup folder. '
          'Credit accounts are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Print & save summary'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final cycleKey = 'stock_cycle_start_${box.id}';
    DateTime? cycleStart;
    final raw = HiveDatabase.settingsBox.get(cycleKey);
    if (raw is String) {
      cycleStart = DateTime.tryParse(raw);
    } else if (raw is DateTime) {
      cycleStart = raw;
    }

    final salesState = context.read<SalesBloc>().state;
    final txs = salesState.allTransactions.where((t) {
      if (t.boxId != box.id) return false;
      if (cycleStart == null) return true;
      return !t.timestamp.isBefore(cycleStart);
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final creditState = context.read<CreditBloc>().state;
    final summary = StockSalesSummary.build(
      productName: box.productName,
      boxId: box.id,
      transactions: txs,
      creditAccounts: creditState.accounts,
    );

    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final savedPath = await BackupService.writeNamedFile(
      'stock_summary_${box.productName}_$stamp.txt',
      summary,
    );

    final salesBloc = context.read<SalesBloc>();

    var printed = false;
    try {
      printed = await PrinterHelper().printPlainText(summary);
    } catch (_) {}

    await HiveDatabase.settingsBox.put(cycleKey, DateTime.now().toIso8601String());
    salesBloc.add(const LoadSalesEvent());

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          printed
              ? 'Stock summary printed.${savedPath != null ? ' Saved to backup.' : ''}'
              : 'Printer unavailable. Summary saved${savedPath != null ? ' to $savedPath' : ' in backup folder'}.',
        ),
        backgroundColor: printed ? Colors.green : Colors.orange[800],
      ),
    );
  }

  void _showRestockDialog(BuildContext context, InventoryBoxModel box) {
    int additionalStock = 50;
    final controller = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock ${box.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: ${box.currentStock} units'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Add Quantity',
                hintText: 'e.g. 50',
              ),
              onChanged: (val) {
                final n = int.tryParse(val);
                if (n != null && n > 0) {
                  additionalStock = n;
                }
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [10, 25, 50, 100].map((qty) {
                return ActionChip(
                  label: Text('+$qty'),
                  onPressed: () {
                    controller.text = qty.toString();
                    additionalStock = qty;
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (additionalStock > 0) {
                context.read<InventoryBloc>().add(RestockBoxEvent(
                      boxId: box.id,
                      additionalStock: additionalStock,
                    ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Confirm Restock'),
          ),
        ],
      ),
    );
  }

  void _showBarcodeDialog(BuildContext context, InventoryBoxModel box) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(box.productName, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: PrettyQrView.data(
                data: box.barcode,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              box.barcode,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Default Price: ${MoneyFormat.format(box.defaultUnitPrice)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
