import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../data/models/sales_transaction_model.dart';
import 'sales_event.dart';

enum SalesStatus { initial, loading, loaded, error }

class ProductSalesSummary extends Equatable {
  final String productName;
  final int unitsSold;
  final double totalRevenue;
  final int transactionCount;

  const ProductSalesSummary({
    required this.productName,
    required this.unitsSold,
    required this.totalRevenue,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [productName, unitsSold, totalRevenue, transactionCount];
}

class SalesState extends Equatable {
  final SalesStatus status;
  final List<SalesTransactionModel> allTransactions;
  final List<SalesTransactionModel> filteredTransactions;
  final DateFilterType currentFilter;
  final DateTimeRange? customDateRange;
  final double totalRevenue;
  final int totalUnitsSold;
  final List<ProductSalesSummary> productBreakdown;
  final String? errorMessage;
  final String? successMessage;
  final SalesTransactionModel? lastRecordedTransaction;

  const SalesState({
    this.status = SalesStatus.initial,
    this.allTransactions = const [],
    this.filteredTransactions = const [],
    this.currentFilter = DateFilterType.today,
    this.customDateRange,
    this.totalRevenue = 0.0,
    this.totalUnitsSold = 0,
    this.productBreakdown = const [],
    this.errorMessage,
    this.successMessage,
    this.lastRecordedTransaction,
  });

  SalesState copyWith({
    SalesStatus? status,
    List<SalesTransactionModel>? allTransactions,
    List<SalesTransactionModel>? filteredTransactions,
    DateFilterType? currentFilter,
    DateTimeRange? customDateRange,
    double? totalRevenue,
    int? totalUnitsSold,
    List<ProductSalesSummary>? productBreakdown,
    String? errorMessage,
    String? successMessage,
    SalesTransactionModel? lastRecordedTransaction,
    bool clearMessages = false,
  }) {
    return SalesState(
      status: status ?? this.status,
      allTransactions: allTransactions ?? this.allTransactions,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      currentFilter: currentFilter ?? this.currentFilter,
      customDateRange: customDateRange ?? this.customDateRange,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalUnitsSold: totalUnitsSold ?? this.totalUnitsSold,
      productBreakdown: productBreakdown ?? this.productBreakdown,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      lastRecordedTransaction: lastRecordedTransaction ?? this.lastRecordedTransaction,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allTransactions,
        filteredTransactions,
        currentFilter,
        customDateRange,
        totalRevenue,
        totalUnitsSold,
        productBreakdown,
        errorMessage,
        successMessage,
        lastRecordedTransaction,
      ];
}
