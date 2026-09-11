import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/money_sound.dart';
import '../../../credit/data/models/credit_account_model.dart';
import '../../../credit/presentation/bloc/credit_bloc.dart';
import '../../../credit/presentation/bloc/credit_event.dart';
import '../../../credit/presentation/bloc/credit_state.dart';
import '../../../credit/presentation/pages/credit_accounts_page.dart';
import '../../../sales/data/models/sales_transaction_model.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_event.dart';
import '../../data/models/inventory_box_model.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';

class QuickSaleModal extends StatefulWidget {
  final InventoryBoxModel box;

  const QuickSaleModal({super.key, required this.box});

  static Future<bool?> show(BuildContext context, InventoryBoxModel box) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickSaleModal(box: box),
    );
  }

  @override
  State<QuickSaleModal> createState() => _QuickSaleModalState();
}

class _QuickSaleModalState extends State<QuickSaleModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _quantityController;

  int _quantity = 1;
  final double _unitPrice = AppConstants.defaultUnitPrice;
  String? _paymentMethod;
  String? _mobileNetwork;
  CreditAccountModel? _creditAccount;
  bool _isNewCreditAccount = false;

  @override
  void initState() {
    super.initState();
    _quantity = widget.box.currentStock > 0 ? 1 : 0;
    _quantityController = TextEditingController(text: _quantity.toString());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double get _totalAmount => _quantity * _unitPrice;

  void _updateQuantity(int newQty) {
    if (newQty < 1) newQty = 1;
    if (newQty > widget.box.currentStock) newQty = widget.box.currentStock;
    setState(() {
      _quantity = newQty;
      _quantityController.text = newQty.toString();
    });
  }

  Future<void> _selectCash() async {
    setState(() {
      _paymentMethod = 'cash';
      _mobileNetwork = null;
      _creditAccount = null;
      _isNewCreditAccount = false;
    });
  }

  Future<void> _selectMobileMoney() async {
    final network = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Mobile money network'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'mtn'),
            child: const ListTile(
              leading: Icon(Icons.phone_android, color: Color(0xFFFFCC00)),
              title: Text('MTN'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'airtel'),
            child: const ListTile(
              leading: Icon(Icons.phone_android, color: Color(0xFFE60000)),
              title: Text('Airtel'),
            ),
          ),
        ],
      ),
    );
    if (network == null || !mounted) return;
    setState(() {
      _paymentMethod = 'mobile_money';
      _mobileNetwork = network;
      _creditAccount = null;
      _isNewCreditAccount = false;
    });
  }

  Future<void> _selectCredit() async {
    final creditState = context.read<CreditBloc>().state;
    if (creditState.creditDisabledForAmount(_totalAmount)) {
      return;
    }
    final picked = await CreditAccountPicker.show(context, amount: _totalAmount);
    if (picked == null || !mounted) return;
    setState(() {
      _paymentMethod = 'credit';
      _mobileNetwork = null;
      _isNewCreditAccount = picked.id.startsWith('new:');
      _creditAccount = picked;
    });
  }

  Future<void> _confirmSale() async {
    if (widget.box.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item is out of stock! Cannot complete sale.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a mode of payment first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_paymentMethod == 'mobile_money' && _mobileNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose MTN or Airtel.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_paymentMethod == 'credit' && _creditAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select or create a credit account.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    if (_quantity > widget.box.currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Quantity ($_quantity) exceeds available stock (${widget.box.currentStock})!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? creditAccountId;
    String? creditPersonName;
    if (_paymentMethod == 'credit' && _creditAccount != null) {
      final now = DateTime.now();
      final purchase = CreditPurchaseModel(
        productName: widget.box.productName,
        date: now,
        quantity: _quantity,
        amount: _totalAmount,
      );
      final CreditAccountModel saved;
      if (_isNewCreditAccount) {
        saved = CreditAccountModel(
          id: const Uuid().v4(),
          personName: _creditAccount!.personName,
          openedAt: now,
          amountOwed: _totalAmount,
          purchases: [purchase],
        );
      } else {
        saved = _creditAccount!.copyWith(
          amountOwed: _creditAccount!.amountOwed + _totalAmount,
          purchases: [..._creditAccount!.purchases, purchase],
        );
      }
      creditAccountId = saved.id;
      creditPersonName = saved.personName;
      context.read<CreditBloc>().add(SaveCreditAccountEvent(saved));
    }

    final transaction = SalesTransactionModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      boxId: widget.box.id,
      productName: widget.box.productName,
      quantitySold: _quantity,
      unitPrice: _unitPrice,
      totalAmount: _totalAmount,
      paymentMethod: _paymentMethod!,
      mobileNetwork: _mobileNetwork,
      creditAccountId: creditAccountId,
      creditPersonName: creditPersonName,
    );

    context.read<InventoryBloc>().add(DeductStockEvent(
          boxId: widget.box.id,
          quantity: _quantity,
        ));
    context.read<SalesBloc>().add(RecordTransactionEvent(transaction));

    await MoneySound.play();
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 80);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isOutOfStock = widget.box.currentStock <= 0;
    final remainingAfterSale = widget.box.currentStock - _quantity;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.inventory_2_rounded,
                        color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.box.productName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${MoneyFormat.format(_unitPrice)} per product',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOutOfStock
                              ? 'Out of Stock'
                              : '${widget.box.currentStock} in stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOutOfStock
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              if (isOutOfStock) ...[
                const Text(
                    'Please restock this product before recording new transactions.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ] else ...[
                const Text(
                  'Quantity Sold',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _quantity > 1
                          ? () => _updateQuantity(_quantity - 1)
                          : null,
                      icon: const Icon(Icons.remove),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter quantity';
                          }
                          final parsed = int.tryParse(val);
                          if (parsed == null || parsed <= 0) {
                            return 'Must be > 0';
                          }
                          if (parsed > widget.box.currentStock) {
                            return 'Max is ${widget.box.currentStock}';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed >= 0) {
                            setState(() {
                              _quantity = parsed;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _quantity < widget.box.currentStock
                          ? () => _updateQuantity(_quantity + 1)
                          : null,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                        foregroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Mode of payment',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                BlocBuilder<CreditBloc, CreditState>(
                  builder: (context, creditState) {
                    final creditDisabled =
                        creditState.creditDisabledForAmount(_totalAmount);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PaymentChip(
                                label: 'Cash',
                                selected: _paymentMethod == 'cash',
                                onTap: _selectCash,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PaymentChip(
                                label: 'Mobile money',
                                selected: _paymentMethod == 'mobile_money',
                                onTap: _selectMobileMoney,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PaymentChip(
                                label: 'Credit',
                                selected: _paymentMethod == 'credit',
                                enabled: !creditDisabled,
                                onTap: creditDisabled ? null : _selectCredit,
                              ),
                            ),
                          ],
                        ),
                        if (creditDisabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Credit is unavailable: 3 people are at the ${MoneyFormat.format(AppConstants.creditLimitPerAccount)} limit.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        if (_paymentMethod == 'mobile_money' &&
                            _mobileNetwork != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Network: ${_mobileNetwork!.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (_paymentMethod == 'credit' &&
                            _creditAccount != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _isNewCreditAccount
                                  ? 'New account: ${_creditAccount!.personName}'
                                  : 'Account: ${_creditAccount!.personName}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_quantity × ${MoneyFormat.format(_unitPrice)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Remaining stock: $remainingAfterSale',
                            style: TextStyle(
                              fontSize: 12,
                              color: remainingAfterSale <= 5
                                  ? Colors.orange[800]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL AMOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            MoneyFormat.format(_totalAmount),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _confirmSale,
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: const Text(
                    'Record Transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaymentChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? Colors.grey[200]
        : selected
            ? AppTheme.primaryColor
            : Colors.grey[100];
    final fg = !enabled
        ? Colors.grey[500]
        : selected
            ? Colors.white
            : Colors.black87;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected && enabled
                ? AppTheme.primaryColor
                : Colors.grey[300]!,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}
