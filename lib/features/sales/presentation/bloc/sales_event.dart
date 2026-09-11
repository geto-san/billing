import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../data/models/sales_transaction_model.dart';

enum DateFilterType { today, yesterday, custom }

abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class LoadSalesEvent extends SalesEvent {
  final DateFilterType filter;
  final DateTimeRange? customRange;

  const LoadSalesEvent({
    this.filter = DateFilterType.today,
    this.customRange,
  });

  @override
  List<Object?> get props => [filter, customRange];
}

class ChangeDateFilterEvent extends SalesEvent {
  final DateFilterType filter;
  final DateTimeRange? customRange;

  const ChangeDateFilterEvent(this.filter, {this.customRange});

  @override
  List<Object?> get props => [filter, customRange];
}

class RecordTransactionEvent extends SalesEvent {
  final SalesTransactionModel transaction;
  const RecordTransactionEvent(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class DeleteTransactionEvent extends SalesEvent {
  final String transactionId;
  final String? boxId;
  final int? quantityToRestore;

  const DeleteTransactionEvent({
    required this.transactionId,
    this.boxId,
    this.quantityToRestore,
  });

  @override
  List<Object?> get props => [transactionId, boxId, quantityToRestore];
}
