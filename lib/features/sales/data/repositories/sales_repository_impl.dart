import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/backup_service.dart';
import '../../domain/repositories/sales_repository.dart';
import '../models/sales_transaction_model.dart';

class SalesRepositoryImpl implements SalesRepository {
  @override
  Future<Either<Failure, void>> recordTransaction(
      SalesTransactionModel transaction) async {
    try {
      final box = HiveDatabase.salesTransactionsBox;
      await box.put(transaction.id, transaction);
      await BackupService.appendTransaction(transaction);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SalesTransactionModel>>> getTransactions() async {
    try {
      final box = HiveDatabase.salesTransactionsBox;
      final transactions = box.values.toList();
      // Sort newest first
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return Right(transactions);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String transactionId) async {
    try {
      final box = HiveDatabase.salesTransactionsBox;
      await box.delete(transactionId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
