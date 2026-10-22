import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_page.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_firestore_datasource.dart';
import '../models/transaction_dto.dart';

/// Implementação de [TransactionRepository] sobre o Firestore.
///
/// Recebe os tipos do Firestore do datasource e devolve só entidades de
/// domínio — nenhum `QuerySnapshot` sai daqui.
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._datasource);

  final TransactionFirestoreDatasource _datasource;

  @override
  Stream<List<Transaction>> watchAll(String userId) {
    return _datasource
        .watchByUser(userId)
        .map((snapshot) => snapshot.docs.map(TransactionDto.fromDoc).toList());
  }

  @override
  Future<TransactionPage> getPage({
    required String userId,
    int pageSize = 20,
    Object? after,
    TransactionFilter filter = const TransactionFilter(),
  }) async {
    final snapshot = await _datasource.getPage(
      userId: userId,
      pageSize: pageSize,
      startAfter: after as DocumentSnapshot<Map<String, dynamic>>?,
      category: filter.category?.name,
      startDate: filter.startDate,
      endDate: filter.endDate,
    );

    final docs = snapshot.docs;
    return TransactionPage(
      items: docs.map(TransactionDto.fromDoc).toList(),
      hasMore: docs.length == pageSize,
      // Sem documentos, mantém o cursor anterior: nada mudou.
      cursor: docs.isEmpty ? after : docs.last,
    );
  }

  @override
  Future<Transaction?> getById(String id) async {
    final doc = await _datasource.getById(id);
    return doc == null ? null : TransactionDto.fromDoc(doc);
  }

  @override
  Future<void> add(Transaction transaction) {
    return _datasource.add(TransactionDto.toMap(transaction));
  }

  @override
  Future<void> update(Transaction transaction) {
    final id = transaction.id;
    if (id == null) {
      throw ArgumentError('Não dá pra atualizar uma transação sem id.');
    }
    return _datasource.update(id, TransactionDto.toMap(transaction));
  }

  @override
  Future<void> delete(String id) => _datasource.delete(id);
}
