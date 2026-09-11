import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../inventory/data/models/inventory_box_model.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_state.dart';
import '../../../inventory/presentation/widgets/quick_sale_modal.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_state.dart';
import '../../../sales/presentation/pages/sales_dashboard_page.dart';
import '../../../inventory/presentation/pages/inventory_boxes_page.dart';
import '../../../inventory/presentation/pages/printable_barcodes_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: const [
          _ScanAndSellView(),
          SalesDashboardPage(),
          InventoryBoxesPage(),
          PrintableBarcodesPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan & Sell',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print),
            label: 'Barcodes',
          ),
        ],
      ),
    );
  }
}

class _ScanAndSellView extends StatefulWidget {
  const _ScanAndSellView();

  @override
  State<_ScanAndSellView> createState() => _ScanAndSellViewState();
}

class _ScanAndSellViewState extends State<_ScanAndSellView> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
    autoStart: false,
  );

  bool _scannerReady = false;
  bool _isCameraOn = true;
  bool _isFlashOn = false;
  bool _isModalOpen = false;

  final Map<String, DateTime> _lastScanTimes = {};
  final DateFormat _timeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _scannerReady = true);
      if (_isCameraOn) {
        await _scannerController.start();
      }
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isModalOpen) return;

    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        final rawValue = barcode.rawValue!.trim();

        // 2-second cooldown per identical barcode
        if (_lastScanTimes.containsKey(rawValue)) {
          final lastScan = _lastScanTimes[rawValue]!;
          if (now.difference(lastScan).inMilliseconds < 1500) {
            continue;
          }
        }
        _lastScanTimes[rawValue] = now;

        await _processBarcode(rawValue);
        break;
      }
    }
  }

  Future<void> _processBarcode(String barcode) async {
    if (_isModalOpen) return;

    final invState = context.read<InventoryBloc>().state;
    final matchedBox = invState.findBoxByBarcode(barcode);

    if (matchedBox != null) {
      // Barcode matched one of the inventory boxes!
      _isModalOpen = true;

      // Android vibration
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 60);
      }

      if (!mounted) return;

      final result = await QuickSaleModal.show(context, matchedBox);
      _isModalOpen = false;

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Sale recorded for ${matchedBox.productName}! Inventory deducted.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Unknown barcode
      _isModalOpen = true;
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Unknown Barcode'),
            ],
          ),
          content: Text(
            'Scanned barcode "$barcode" is not assigned to any of the 3 inventory boxes.\n\nPlease assign it in the Inventory tab or scan a valid box.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/inventory');
              },
              child: const Text('Go to Inventory'),
            ),
          ],
        ),
      );

      _isModalOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Scan & Sell',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // SCANNER VIEW (TOP CAMERA SECTION)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: _buildScannerSection(),
          ),

          _buildQuickBoxShortcuts(),

          // RECENT ACTIVITY / SALES TRANSACTIONS FEED
          Expanded(
            child: _buildRecentSalesStream(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_scannerReady)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
          if (!_isCameraOn) _buildCameraOffState(),

          // Camera Control Buttons
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon:
                        _isFlashOn ? Icons.flash_off : Icons.flash_on,
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                _buildOverlayButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  onPressed: () {
                    setState(() => _isCameraOn = !_isCameraOn);
                    if (_isCameraOn) {
                      _scannerController.start();
                    } else {
                      _scannerController.stop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Central Bounding Target Box
          if (_isCameraOn)
            Center(
              child: Container(
                width: 230,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.6),
                      width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                    const Center(
                      child: Text(
                        'Align Box Barcode',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white70, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Camera is turned off',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: const Icon(Icons.videocam, size: 18),
            label: const Text('Turn on Camera'),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight)
                ? const BorderSide(color: Color(0xFF03DAC6), width: 4)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Color(0xFF03DAC6), width: 4)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft)
                ? const BorderSide(color: Color(0xFF03DAC6), width: 4)
                : BorderSide.none,
            right: (alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Color(0xFF03DAC6), width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickBoxShortcuts() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'QUICK SELECT BOX:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BlocBuilder<InventoryBloc, InventoryState>(
            builder: (context, state) {
              final boxes = state.boxes;
              if (boxes.isEmpty) {
                return const Text('Loading boxes...',
                    style: TextStyle(fontSize: 12));
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: boxes.map((box) {
                    final isLow = box.currentStock < (box.initialStock * 0.25);
                    final isOut = box.currentStock <= 0;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        elevation: 1,
                        avatar: Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: isOut
                              ? Colors.red
                              : (isLow
                                  ? Colors.orange
                                  : AppTheme.primaryColor),
                        ),
                        label: Text(
                          '${box.productName} (${box.currentStock})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOut ? Colors.red : Colors.black87,
                          ),
                        ),
                        backgroundColor: isOut
                            ? Colors.red[50]
                            : AppTheme.primaryColor.withOpacity(0.06),
                        side: BorderSide(
                          color: isOut
                              ? Colors.red[300]!
                              : AppTheme.primaryColor.withOpacity(0.2),
                        ),
                        onPressed: () => _openModalForBox(box),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openModalForBox(InventoryBoxModel box) async {
    _isModalOpen = true;
    final result = await QuickSaleModal.show(context, box);
    _isModalOpen = false;

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Sale recorded for ${box.productName}!'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildRecentSalesStream() {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, salesState) {
        final recentTransactions = salesState.allTransactions.take(20).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT TRANSACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${recentTransactions.length} recorded',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: recentTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.point_of_sale_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions recorded yet',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Scan a box barcode above to record sales instantly.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: recentTransactions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 48),
                      itemBuilder: (context, index) {
                        final tx = recentTransactions[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.check,
                                color: AppTheme.primaryColor, size: 20),
                          ),
                          title: Text(
                            tx.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${tx.quantitySold} units • ${tx.paymentLabel} • ${_timeFormat.format(tx.timestamp)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Text(
                            MoneyFormat.format(tx.totalAmount),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
