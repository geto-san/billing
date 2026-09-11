import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
import '../../../sales/data/models/sales_transaction_model.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_event.dart';
import '../../data/models/credit_account_model.dart';
import '../bloc/credit_bloc.dart';
import '../bloc/credit_event.dart';
import '../bloc/credit_state.dart';

class CreditAccountsPage extends StatelessWidget {
  const CreditAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Accounts',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: BlocBuilder<CreditBloc, CreditState>(
        builder: (context, state) {
          if (state.accounts.isEmpty) {
            return const Center(
              child: Text('No credit accounts yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: state.accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final account = state.accounts[index];
              final remaining = state.remainingCredit(account);
              final isCleared = account.amountOwed <= 0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCleared ? Colors.green[200]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.personName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isCleared)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              'CLEARED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        else
                          Text(
                            MoneyFormat.format(account.amountOwed),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Opened ${dateFmt.format(account.openedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (!isCleared)
                      Text(
                        'Limit ${MoneyFormat.format(AppConstants.creditLimitPerAccount)} • Remaining ${MoneyFormat.format(remaining)}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 12),
                    if (account.purchases.isEmpty)
                      Text('No products on this account yet.',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13))
                    else
                      ...account.purchases.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${p.productName} • ${p.quantity} pcs • ${dateFmt.format(p.date)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                MoneyFormat.format(p.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isCleared)
                          TextButton.icon(
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text('Mark as cleared'),
                            onPressed: () =>
                                _confirmSettle(context, account, state),
                          ),
                        if (isCleared)
                          TextButton.icon(
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: Colors.red[400]),
                            label: Text('Delete account',
                                style: TextStyle(color: Colors.red[400])),
                            onPressed: () =>
                                _confirmDelete(context, account),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Asks how the credit was paid (cash / MTN / Airtel), then records a
  /// revenue transaction and zeros out the account balance.
  Future<void> _confirmSettle(
    BuildContext context,
    CreditAccountModel account,
    CreditState state,
  ) async {
    final result = await showDialog<_SettleResult>(
      context: context,
      builder: (ctx) => _SettlePaymentDialog(account: account),
    );
    if (result == null || !context.mounted) return;

    // 1. Zero out the account balance in the credit store.
    context.read<CreditBloc>().add(SettleCreditAccountEvent(account.id));

    // 2. Record a revenue transaction so the cleared amount appears in
    //    the sales dashboard under cash / mobile money.
    final settlement = SalesTransactionModel(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      boxId: 'credit_settlement',
      productName: 'Credit settled: ${account.personName}',
      quantitySold: 0,
      unitPrice: account.amountOwed,
      totalAmount: account.amountOwed,
      paymentMethod: 'credit_settled',
      mobileNetwork: result.mobileNetwork,
      creditAccountId: account.id,
      creditPersonName: account.personName,
    );
    context.read<SalesBloc>().add(RecordTransactionEvent(settlement));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${account.personName}\'s account cleared — '
            '${MoneyFormat.format(account.amountOwed)} added to revenue.',
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, CreditAccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete credit account?'),
        content: Text(
          'This will permanently remove ${account.personName}\'s account from the list. '
          'The account balance is already cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CreditBloc>().add(DeleteCreditAccountEvent(account.id));
    }
  }
}

class _SettleResult {
  final String? mobileNetwork;
  const _SettleResult({this.mobileNetwork});
}

class _SettlePaymentDialog extends StatefulWidget {
  final CreditAccountModel account;
  const _SettlePaymentDialog({required this.account});

  @override
  State<_SettlePaymentDialog> createState() => _SettlePaymentDialogState();
}

class _SettlePaymentDialogState extends State<_SettlePaymentDialog> {
  String? _method; // 'cash' | 'mtn' | 'airtel'

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Clear ${widget.account.personName}\'s account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount: ${MoneyFormat.format(widget.account.amountOwed)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'How was the credit paid?',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          _MethodTile(
            label: 'Cash',
            icon: Icons.payments_outlined,
            iconColor: Colors.green[700]!,
            selected: _method == 'cash',
            onTap: () => setState(() => _method = 'cash'),
          ),
          const SizedBox(height: 8),
          _MethodTile(
            label: 'Mobile Money — MTN',
            icon: Icons.phone_android,
            iconColor: const Color(0xFFFFCC00),
            selected: _method == 'mtn',
            onTap: () => setState(() => _method = 'mtn'),
          ),
          const SizedBox(height: 8),
          _MethodTile(
            label: 'Mobile Money — Airtel',
            icon: Icons.phone_android,
            iconColor: const Color(0xFFE60000),
            selected: _method == 'airtel',
            onTap: () => setState(() => _method = 'airtel'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _method == null
              ? null
              : () => Navigator.pop(
                    context,
                    _SettleResult(
                      mobileNetwork: _method == 'cash' ? null : _method,
                    ),
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm & add to revenue'),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey[200]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.w500,
                  color:
                      selected ? AppTheme.primaryColor : Colors.black87,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Credit account picker (used in QuickSaleModal — unchanged below this line)
// ---------------------------------------------------------------------------

class CreditAccountPicker {
  static Future<CreditAccountModel?> show(
    BuildContext context, {
    required double amount,
  }) {
    return showModalBottomSheet<CreditAccountModel?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreditPickerSheet(amount: amount),
    );
  }
}

class _CreditPickerSheet extends StatefulWidget {
  final double amount;
  const _CreditPickerSheet({required this.amount});

  @override
  State<_CreditPickerSheet> createState() => _CreditPickerSheetState();
}

class _CreditPickerSheetState extends State<_CreditPickerSheet> {
  bool _creatingNew = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: BlocBuilder<CreditBloc, CreditState>(
        builder: (context, state) {
          final usable = state.openAccounts
              .where((a) => state.remainingCredit(a) >= widget.amount)
              .toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Credit account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Charge ${MoneyFormat.format(widget.amount)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              if (!_creatingNew) ...[
                if (state.canOpenNewAccount)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_add_alt_1,
                        color: AppTheme.primaryColor),
                    title: const Text('Create a new credit account'),
                    subtitle: Text(
                      '${state.openAccounts.length}/${AppConstants.maxCreditAccounts} people in use',
                    ),
                    onTap: () => setState(() => _creatingNew = true),
                  ),
                if (usable.isNotEmpty) ...[
                  const Divider(),
                  const Text('Use an existing account',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...usable.map((account) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(account.personName),
                      subtitle: Text(
                        'Owes ${MoneyFormat.format(account.amountOwed)} • Remaining ${MoneyFormat.format(state.remainingCredit(account))}',
                      ),
                      onTap: () => Navigator.pop(context, account),
                    );
                  }),
                ] else if (!state.canOpenNewAccount)
                  const Text(
                    'No existing account has enough remaining credit for this sale.',
                  ),
              ] else ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Person name',
                    hintText: 'e.g. John Okello',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _creatingNew = false),
                      child: const Text('Back'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(
                          context,
                          CreditAccountModel(
                            id: 'new:$name',
                            personName: name,
                            openedAt: DateTime.now(),
                            amountOwed: 0,
                            purchases: const [],
                          ),
                        );
                      },
                      child: const Text('Use this name'),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
