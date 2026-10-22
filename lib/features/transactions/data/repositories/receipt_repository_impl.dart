import 'dart:io';

import '../../domain/repositories/receipt_repository.dart';
import '../datasources/receipt_storage_datasource.dart';

/// Implementação de [ReceiptRepository] sobre o Firebase Storage.
class ReceiptRepositoryImpl implements ReceiptRepository {
  ReceiptRepositoryImpl(this._datasource);

  final ReceiptStorageDatasource _datasource;

  @override
  Future<String> upload({required String filePath, required String userId}) {
    return _datasource.upload(File(filePath), userId);
  }

  @override
  Future<void> delete(String url) => _datasource.delete(url);
}
