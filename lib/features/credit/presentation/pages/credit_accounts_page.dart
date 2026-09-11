import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money_format.dart';
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
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
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
                        Text(
                          MoneyFormat.format(account.amountOwed),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: account.amountOwed > 0
                                ? Colors.orange[800]
                                : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Opened ${dateFmt.format(account.openedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'Limit ${MoneyFormat.format(AppConstants.creditLimitPerAccount)} • Remaining ${MoneyFormat.format(remaining)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    if (account.purchases.isEmpty)
                      Text('No products on this account yet.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13))
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
                    if (account.amountOwed > 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            context
                                .read<CreditBloc>()
                                .add(SettleCreditAccountEvent(account.id));
                          },
                          child: const Text('Mark as cleared'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
