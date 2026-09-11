import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/sales/data/models/sales_transaction_model.dart';
import '../constants/app_constants.dart';
import 'money_format.dart';

class BackupService {
  BackupService._();

  static Future<void> ensurePermissions() async {
    try {
      await Permission.storage.request();
    } catch (_) {}
    try {
      await Permission.manageExternalStorage.request();
    } catch (_) {}
  }

  static Future<Directory> backupDirectory() async {
    await ensurePermissions();

    final candidates = <Directory>[
      Directory('/storage/emulated/0/${AppConstants.backupFolderName}'),
      Directory(
          '/storage/emulated/0/Documents/${AppConstants.backupFolderName}'),
    ];

    for (final dir in candidates) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {}
    }

    final fallbackRoot = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir =
        Directory('${fallbackRoot.path}/${AppConstants.backupFolderName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> appendTransaction(SalesTransactionModel tx) async {
    try {
      final dir = await backupDirectory();
      final day = DateFormat('yyyy-MM-dd').format(tx.timestamp);
      final file = File('${dir.path}/sales_$day.txt');
      final line =
          '${DateFormat('yyyy-MM-dd HH:mm:ss').format(tx.timestamp)} | '
          '${tx.productName} | qty ${tx.quantitySold} | '
          '${MoneyFormat.format(tx.totalAmount)} | ${tx.paymentLabel}\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static Future<String?> writeNamedFile(String fileName, String contents) async {
    try {
      final dir = await backupDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(contents, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
