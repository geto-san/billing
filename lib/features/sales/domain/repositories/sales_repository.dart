import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../data/models/sales_transaction_model.dart';

abstract class SalesRepository {
  Future<Either<Failure, void>> recordTransaction(SalesTransactionModel transaction);
  Future<Either<Failure, List<SalesTransactionModel>>> getTransactions();
  Future<Either<Failure, void>> deleteTransaction(String transactionId);
}
