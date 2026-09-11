import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_state.dart';
import '../../data/models/inventory_box_model.dart';

class PrintableBarcodesPage extends StatelessWidget {
  const PrintableBarcodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printable Box Barcodes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          final boxes = state.boxes;
          if (boxes.isEmpty) {
            return const Center(child: Text('No inventory boxes found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Point another camera at these QR/Barcodes or print "barcodes.txt" to label your boxes.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...boxes.map((box) => _PrintableBarcodeCard(box: box)),
            ],
          );
        },
      ),
    );
  }
}

class _PrintableBarcodeCard extends StatelessWidget {
  final InventoryBoxModel box;

  const _PrintableBarcodeCard({required this.box});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                box.productName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Default: ${MoneyFormat.format(box.defaultUnitPrice)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Box ID: ${box.id}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              Text(
                'Stock: ${box.currentStock} / ${box.initialStock}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Render QR / Barcode
          Container(
            width: 170,
            height: 170,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black87, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PrettyQrView.data(
              data: box.barcode,
            ),
          ),
          const SizedBox(height: 12),

          // Barcode String text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              box.barcode,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
