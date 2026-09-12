import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../credit/presentation/bloc/credit_bloc.dart';
import '../../../credit/presentation/bloc/credit_state.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_event.dart';
import '../../../inventory/presentation/bloc/inventory_state.dart';
import '../../data/models/sales_transaction_model.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';

class SalesDashboardPage extends StatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  State<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends State<SalesDashboardPage> {
  final _dateFormat = DateFormat('MMM d, yyyy');
  final _timeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(const LoadSalesEvent());
  }

  void _selectDateFilter(DateFilterType type) async {
    if (type == DateFilterType.custom) {
      final now = DateTime.now();
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 2),
        initialDateRange: DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        ),
      );
      if (pickedRange != null && mounted) {
        context.read<SalesBloc>().add(ChangeDateFilterEvent(
              DateFilterType.custom,
              customRange: pickedRange,
            ));
      }
    } else {
      context.read<SalesBloc>().add(ChangeDateFilterEvent(type));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Analytics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<SalesBloc>().add(const LoadSalesEvent());
              context.read<InventoryBloc>().add(LoadInventoryEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<SalesBloc, SalesState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, salesState) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<SalesBloc>().add(const LoadSalesEvent());
              context.read<InventoryBloc>().add(LoadInventoryEvent());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateFilterBar(salesState),
                  const SizedBox(height: 16),
                  _buildMetricsRow(salesState),
                  const SizedBox(height: 20),
                  // Payments section needs live credit data — use BlocBuilder here
                  BlocBuilder<CreditBloc, CreditState>(
                    builder: (context, creditState) =>
                        _buildPaymentSplit(salesState, creditState),
                  ),
                  const SizedBox(height: 20),
                  _buildCurrentStockSection(),
                  const SizedBox(height: 20),
                  _buildProductBreakdownSection(salesState),
                  const SizedBox(height: 20),
                  _buildTransactionsLogSection(salesState),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date filter bar
  // ---------------------------------------------------------------------------

  Widget _buildDateFilterBar(SalesState state) {
    String customLabel = 'Custom Range';
    if (state.currentFilter == DateFilterType.custom &&
        state.customDateRange != null) {
      customLabel =
          '${_dateFormat.format(state.customDateRange!.start)} – ${_dateFormat.format(state.customDateRange!.end)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(
              label: 'Today',
              isSelected: state.currentFilter == DateFilterType.today,
              onTap: () => _selectDateFilter(DateFilterType.today),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildFilterTab(
              label: 'Yesterday',
              isSelected: state.currentFilter == DateFilterType.yesterday,
              onTap: () => _selectDateFilter(DateFilterType.yesterday),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: state.currentFilter == DateFilterType.custom ? 2 : 1,
            child: _buildFilterTab(
              label: customLabel,
              isSelected: state.currentFilter == DateFilterType.custom,
              icon: Icons.calendar_today,
              onTap: () => _selectDateFilter(DateFilterType.custom),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Metrics row (revenue + units sold)
  // ---------------------------------------------------------------------------

  Widget _buildMetricsRow(SalesState state) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4834DF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL REVENUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.payments,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  MoneyFormat.format(state.totalRevenue),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cash & mobile money only',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'UNITS SOLD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Icon(Icons.shopping_bag_outlined,
                        color: AppTheme.primaryColor, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${state.totalUnitsSold}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'items tracked',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Payments split
  // Settlements are merged into their respective payment method totals.
  // Credit (unpaid) is read live from CreditBloc so it updates the moment
  // an account is cleared or deleted — no page refresh needed.
  // ---------------------------------------------------------------------------

  Widget _buildPaymentSplit(SalesState salesState, CreditState creditState) {
    final txs = salesState.filteredTransactions;

    // Cash = regular cash sales + credit settlements paid via cash
    final cashTotal = txs
        .where((t) =>
            t.isCash ||
            (t.isCreditSettlement && (t.mobileNetwork == null || t.mobileNetwork!.isEmpty)))
        .fold(0.0, (p, t) => p + t.totalAmount);

    // MTN = regular MTN mobile money + credit settlements paid via MTN
    final mtnTotal = txs
        .where((t) => t.isMtn || t.isSettlementMtn)
        .fold(0.0, (p, t) => p + t.totalAmount);

    // Airtel = regular Airtel mobile money + credit settlements paid via Airtel
    final airtelTotal = txs
        .where((t) => t.isAirtel || t.isSettlementAirtel)
        .fold(0.0, (p, t) => p + t.totalAmount);

    // Live unpaid credit: sum from actual open accounts, not from transaction records.
    // This updates instantly when an account is cleared or deleted.
    final creditUnpaid = creditState.openAccounts
        .fold(0.0, (p, a) => p + a.amountOwed);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PAYMENTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _paymentRow('Cash', cashTotal),
          _paymentRow('Mobile money — MTN', mtnTotal),
          _paymentRow('Mobile money — Airtel', airtelTotal),
          const Divider(height: 20),
          _paymentRow(
            'Credit (unpaid)',
            creditUnpaid,
            amountColor: creditUnpaid > 0 ? Colors.orange[700] : null,
          ),
          if (creditUnpaid > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Pending credit is not counted in revenue until the account is cleared.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  /// Renders a single payment-row label + amount (no transaction count shown).
  Widget _paymentRow(String label, double amount, {Color? amountColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            MoneyFormat.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Current stock
  // ---------------------------------------------------------------------------

  Widget _buildCurrentStockSection() {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, invState) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CURRENT REMAINING STOCK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${invState.boxes.length} Boxes Tracked',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (invState.boxes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No boxes configured.'),
                )
              else
                ...invState.boxes.map((box) {
                  final percent = box.initialStock > 0
                      ? (box.currentStock / box.initialStock).clamp(0.0, 1.0)
                      : 0.0;
                  final isLow =
                      box.currentStock < (box.initialStock * 0.25);
                  final isOut = box.currentStock <= 0;
                  final color = isOut
                      ? Colors.red
                      : (isLow ? Colors.orange : Colors.green);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(box.productName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  '(${box.barcode})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${box.currentStock}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: color,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${box.initialStock} left',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Product breakdown
  // ---------------------------------------------------------------------------

  Widget _buildProductBreakdownSection(SalesState state) {
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
          const Text(
            'PRODUCT SALES BREAKDOWN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          if (state.productBreakdown.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      'No sales recorded for this period',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...state.productBreakdown.map((item) {
              final percent = state.totalRevenue > 0
                  ? (item.totalRevenue / state.totalRevenue) * 100
                  : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.unitsSold} units sold (${item.transactionCount} orders)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          MoneyFormat.format(item.totalRevenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}% of sales',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Transactions log
  // Settlements are shown inside their respective payment group (Cash / MTN /
  // Airtel) and rendered with a green amount + person name instead of a product
  // name.  They cannot be voided.
  // ---------------------------------------------------------------------------

  Widget _buildTransactionsLogSection(SalesState state) {
    final txs = state.filteredTransactions;

    // Cash group: regular cash sales + cash-settled credit
    final cash = txs
        .where((t) =>
            t.isCash ||
            (t.isCreditSettlement &&
                (t.mobileNetwork == null || t.mobileNetwork!.isEmpty)))
        .toList();

    // MTN group: regular MTN sales + MTN-settled credit
    final mtn = txs.where((t) => t.isMtn || t.isSettlementMtn).toList();

    // Airtel group: regular Airtel sales + Airtel-settled credit
    final airtel =
        txs.where((t) => t.isAirtel || t.isSettlementAirtel).toList();

    // Other mobile money (no network set — edge case)
    final otherMm = txs
        .where((t) =>
            t.isMobileMoney && !t.isMtn && !t.isAirtel)
        .toList();

    // Credit unpaid: original credit transactions (not yet settled)
    final credit = txs.where((t) => t.isCredit).toList();

    return Column(
      children: [
        _txGroup('CASH', cash),
        const SizedBox(height: 16),
        _txGroup('MOBILE MONEY — MTN', mtn),
        const SizedBox(height: 16),
        _txGroup('MOBILE MONEY — AIRTEL', airtel),
        if (otherMm.isNotEmpty) ...[
          const SizedBox(height: 16),
          _txGroup('MOBILE MONEY', otherMm),
        ],
        const SizedBox(height: 16),
        _txGroup('CREDIT (UNPAID)', credit),
      ],
    );
  }

  Widget _txGroup(String title, List<SalesTransactionModel> items) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.1,
                ),
              ),
              Text('${items.length} records',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('No records in this group.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13))
          else
            ...items.map((tx) => _txRow(tx)),
        ],
      ),
    );
  }

  Widget _txRow(SalesTransactionModel tx) {
    final isSettlement = tx.isCreditSettlement;
    final displayName = isSettlement
        ? 'Credit settled'
        + (tx.creditPersonName != null && tx.creditPersonName!.isNotEmpty
            ? ': ${tx.creditPersonName}'
            : '')
        : tx.productName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isSettlement ? Colors.green[800] : null,
                  ),
                ),
                Text(
                  '${tx.paymentLabel} • ${_timeFormat.format(tx.timestamp)} • ${_dateFormat.format(tx.timestamp)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyFormat.format(tx.totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSettlement ? Colors.green[700] : null,
                ),
              ),
              if (!isSettlement)
                Text(
                  '${tx.quantitySold} × ${MoneyFormat.format(tx.unitPrice)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
          // Settlements cannot be voided; only regular product sales can.
          if (!isSettlement)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.grey),
              tooltip: 'Void transaction & restore stock',
              onPressed: () => _confirmDeleteTransaction(context, tx),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Void transaction dialog
  // ---------------------------------------------------------------------------

  void _confirmDeleteTransaction(
      BuildContext context, SalesTransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Transaction?'),
        content: Text(
            'Void ${tx.quantitySold} × ${tx.productName} (${MoneyFormat.format(tx.totalAmount)})?\n\n'
            'This will automatically restore ${tx.quantitySold} units back to the box stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InventoryBloc>().add(RestockBoxEvent(
                    boxId: tx.boxId,
                    additionalStock: tx.quantitySold,
                  ));
              context
                  .read<SalesBloc>()
                  .add(DeleteTransactionEvent(transactionId: tx.id));
            },
            child: const Text('Void & Restore Stock'),
          ),
        ],
      ),
    );
  }
}
