import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/credit_account_model.dart';

class CreditState extends Equatable {
  final List<CreditAccountModel> accounts;
  final String? errorMessage;

  const CreditState({
    this.accounts = const [],
    this.errorMessage,
  });

  List<CreditAccountModel> get openAccounts =>
      accounts.where((a) => a.amountOwed > 0).toList();

  bool get canOpenNewAccount =>
      openAccounts.length < AppConstants.maxCreditAccounts;

  bool get allOpenAccountsAtLimit =>
      openAccounts.length >= AppConstants.maxCreditAccounts &&
      openAccounts.every((a) =>
          a.amountOwed >= AppConstants.creditLimitPerAccount - 0.01);

  bool creditDisabledForAmount(double amount) {
    if (amount <= 0) return true;
    if (allOpenAccountsAtLimit) return true;
    final remainingOnExisting = openAccounts
        .where((a) =>
            (AppConstants.creditLimitPerAccount - a.amountOwed) >= amount)
        .isNotEmpty;
    if (remainingOnExisting) return false;
    if (canOpenNewAccount && amount <= AppConstants.creditLimitPerAccount) {
      return false;
    }
    return true;
  }

  double remainingCredit(CreditAccountModel account) {
    final left = AppConstants.creditLimitPerAccount - account.amountOwed;
    return left < 0 ? 0 : left;
  }

  CreditState copyWith({
    List<CreditAccountModel>? accounts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreditState(
      accounts: accounts ?? this.accounts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [accounts, errorMessage];
}
