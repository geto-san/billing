import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/credit_account_model.dart';
import '../../data/repositories/credit_repository.dart';
import 'credit_event.dart';
import 'credit_state.dart';

class CreditBloc extends Bloc<CreditEvent, CreditState> {
  final CreditRepository repository;

  CreditBloc({required this.repository}) : super(const CreditState()) {
    on<LoadCreditAccountsEvent>(_onLoad);
    on<SaveCreditAccountEvent>(_onSave);
    on<SettleCreditAccountEvent>(_onSettle);
    on<DeleteCreditAccountEvent>(_onDelete);
    on<ClearAllCreditEvent>(_onClearAll);
  }

  Future<void> _onLoad(
      LoadCreditAccountsEvent event, Emitter<CreditState> emit) async {
    final result = await repository.getAccounts();
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (accounts) => emit(state.copyWith(accounts: accounts, clearError: true)),
    );
  }

  Future<void> _onSave(
      SaveCreditAccountEvent event, Emitter<CreditState> emit) async {
    final result = await repository.saveAccount(event.account);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {
        final updated = [
          ...state.accounts.where((a) => a.id != event.account.id),
          event.account,
        ]..sort((a, b) => a.personName.compareTo(b.personName));
        emit(state.copyWith(accounts: updated, clearError: true));
      },
    );
  }

  Future<void> _onSettle(
      SettleCreditAccountEvent event, Emitter<CreditState> emit) async {
    CreditAccountModel? account;
    for (final a in state.accounts) {
      if (a.id == event.accountId) {
        account = a;
        break;
      }
    }
    if (account == null) return;
    final settled = account.copyWith(amountOwed: 0);
    final result = await repository.saveAccount(settled);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {
        final updated = state.accounts
            .map((a) => a.id == settled.id ? settled : a)
            .toList();
        emit(state.copyWith(accounts: updated, clearError: true));
      },
    );
  }

  Future<void> _onDelete(
      DeleteCreditAccountEvent event, Emitter<CreditState> emit) async {
    final result = await repository.deleteAccount(event.accountId);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {
        final updated =
            state.accounts.where((a) => a.id != event.accountId).toList();
        emit(state.copyWith(accounts: updated, clearError: true));
      },
    );
  }

  Future<void> _onClearAll(
      ClearAllCreditEvent event, Emitter<CreditState> emit) async {
    final result = await repository.clearAll();
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => emit(const CreditState()),
    );
  }
}
