import 'package:fpdart/fpdart.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../models/credit_account_model.dart';

class CreditRepository {
  Future<Either<Failure, List<CreditAccountModel>>> getAccounts() async {
    try {
      final accounts = HiveDatabase.creditAccountsBox.values.toList()
        ..sort((a, b) => a.personName.compareTo(b.personName));
      return Right(accounts);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> saveAccount(CreditAccountModel account) async {
    try {
      await HiveDatabase.creditAccountsBox.put(account.id, account);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> deleteAccount(String id) async {
    try {
      await HiveDatabase.creditAccountsBox.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> clearAll() async {
    try {
      await HiveDatabase.creditAccountsBox.clear();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
