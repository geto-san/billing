import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../data/models/sales_transaction_model.dart';
import 'sales_event.dart';
import 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final SalesRepository repository;

  SalesBloc({required this.repository}) : super(const SalesState()) {
    on<LoadSalesEvent>(_onLoadSales);
    on<ChangeDateFilterEvent>(_onChangeDateFilter);
    on<RecordTransactionEvent>(_onRecordTransaction);
    on<DeleteTransactionEvent>(_onDeleteTransaction);
  }

  Future<void> _onLoadSales(
      LoadSalesEvent event, Emitter<SalesState> emit) async {
    emit(state.copyWith(status: SalesStatus.loading, clearMessages: true));
    final result = await repository.getTransactions();
    result.fold(
      (failure) => emit(state.copyWith(
        status: SalesStatus.error,
        errorMessage: failure.message,
      )),
      (transactions) {
        final processed = _calculateFiltered(
          transactions,
          event.filter,
          event.customRange ?? state.customDateRange,
        );
        emit(state.copyWith(
          status: SalesStatus.loaded,
          allTransactions: transactions,
          filteredTransactions: processed.filtered,
          currentFilter: event.filter,
          customDateRange: event.customRange ?? state.customDateRange,
          totalRevenue: processed.totalRevenue,
          totalUnitsSold: processed.totalUnitsSold,
          productBreakdown: processed.breakdown,
          clearMessages: true,
        ));
      },
    );
  }

  void _onChangeDateFilter(
      ChangeDateFilterEvent event, Emitter<SalesState> emit) {
    final processed = _calculateFiltered(
      state.allTransactions,
      event.filter,
      event.customRange ?? state.customDateRange,
    );
    emit(state.copyWith(
      filteredTransactions: processed.filtered,
      currentFilter: event.filter,
      customDateRange: event.customRange ?? state.customDateRange,
      totalRevenue: processed.totalRevenue,
      totalUnitsSold: processed.totalUnitsSold,
      productBreakdown: processed.breakdown,
      clearMessages: true,
    ));
  }

  Future<void> _onRecordTransaction(
      RecordTransactionEvent event, Emitter<SalesState> emit) async {
    final result = await repository.recordTransaction(event.transaction);
    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: 'Failed to save transaction: ${failure.message}',
      )),
      (_) {
        final updatedAll = [event.transaction, ...state.allTransactions];
        final processed = _calculateFiltered(
          updatedAll,
          state.currentFilter,
          state.customDateRange,
        );
        emit(state.copyWith(
          allTransactions: updatedAll,
          filteredTransactions: processed.filtered,
          totalRevenue: processed.totalRevenue,
          totalUnitsSold: processed.totalUnitsSold,
          productBreakdown: processed.breakdown,
          lastRecordedTransaction: event.transaction,
          successMessage:
              'Transaction saved: ${event.transaction.quantitySold} × ${event.transaction.productName}',
        ));
      },
    );
  }

  Future<void> _onDeleteTransaction(
      DeleteTransactionEvent event, Emitter<SalesState> emit) async {
    final result = await repository.deleteTransaction(event.transactionId);
    result.fold(
      (failure) => emit(state.copyWith(
        errorMessage: 'Failed to delete transaction: ${failure.message}',
      )),
      (_) {
        final updatedAll = state.allTransactions
            .where((t) => t.id != event.transactionId)
            .toList();
        final processed = _calculateFiltered(
          updatedAll,
          state.currentFilter,
          state.customDateRange,
        );
        emit(state.copyWith(
          allTransactions: updatedAll,
          filteredTransactions: processed.filtered,
          totalRevenue: processed.totalRevenue,
          totalUnitsSold: processed.totalUnitsSold,
          productBreakdown: processed.breakdown,
          successMessage: 'Transaction deleted successfully',
        ));
      },
    );
  }

  _ProcessedSales _calculateFiltered(
    List<SalesTransactionModel> transactions,
    DateFilterType filter,
    DateTimeRange? customRange,
  ) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (filter) {
      case DateFilterType.today:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case DateFilterType.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);
        break;
      case DateFilterType.custom:
        if (customRange != null) {
          start = DateTime(customRange.start.year, customRange.start.month,
              customRange.start.day, 0, 0, 0);
          end = DateTime(customRange.end.year, customRange.end.month,
              customRange.end.day, 23, 59, 59, 999);
        } else {
          start = DateTime(now.year, now.month, now.day, 0, 0, 0);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        }
        break;
    }

    final filtered = transactions.where((t) {
      return t.timestamp.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          t.timestamp.isBefore(end.add(const Duration(milliseconds: 1)));
    }).toList();

    // Sort newest first
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    double totalRevenue = 0.0;
    int totalUnitsSold = 0;
    final Map<String, _ProductStatAccumulator> productMap = {};

    for (final t in filtered) {
      totalRevenue += t.totalAmount;
      totalUnitsSold += t.quantitySold;

      final key = t.productName;
      if (!productMap.containsKey(key)) {
        productMap[key] = _ProductStatAccumulator(
          productName: key,
          unitsSold: 0,
          totalRevenue: 0.0,
          transactionCount: 0,
        );
      }
      final acc = productMap[key]!;
      acc.unitsSold += t.quantitySold;
      acc.totalRevenue += t.totalAmount;
      acc.transactionCount += 1;
    }

    final breakdown = productMap.values.map((acc) {
      return ProductSalesSummary(
        productName: acc.productName,
        unitsSold: acc.unitsSold,
        totalRevenue: acc.totalRevenue,
        transactionCount: acc.transactionCount,
      );
    }).toList();

    // Sort breakdown by units sold descending
    breakdown.sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

    return _ProcessedSales(
      filtered: filtered,
      totalRevenue: totalRevenue,
      totalUnitsSold: totalUnitsSold,
      breakdown: breakdown,
    );
  }
}

class _ProductStatAccumulator {
  final String productName;
  int unitsSold;
  double totalRevenue;
  int transactionCount;

  _ProductStatAccumulator({
    required this.productName,
    required this.unitsSold,
    required this.totalRevenue,
    required this.transactionCount,
  });
}

class _ProcessedSales {
  final List<SalesTransactionModel> filtered;
  final double totalRevenue;
  final int totalUnitsSold;
  final List<ProductSalesSummary> breakdown;

  _ProcessedSales({
    required this.filtered,
    required this.totalRevenue,
    required this.totalUnitsSold,
    required this.breakdown,
  });
}
