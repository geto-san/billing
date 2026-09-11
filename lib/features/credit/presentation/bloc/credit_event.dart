import 'package:equatable/equatable.dart';
import '../../data/models/credit_account_model.dart';

abstract class CreditEvent extends Equatable {
  const CreditEvent();
  @override
  List<Object?> get props => [];
}

class LoadCreditAccountsEvent extends CreditEvent {}

class SaveCreditAccountEvent extends CreditEvent {
  final CreditAccountModel account;
  const SaveCreditAccountEvent(this.account);
  @override
  List<Object?> get props => [account];
}

class SettleCreditAccountEvent extends CreditEvent {
  final String accountId;
  const SettleCreditAccountEvent(this.accountId);
  @override
  List<Object?> get props => [accountId];
}

class ClearAllCreditEvent extends CreditEvent {}

class DeleteCreditAccountEvent extends CreditEvent {
  final String accountId;
  const DeleteCreditAccountEvent(this.accountId);
  @override
  List<Object?> get props => [accountId];
}
