import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_page.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_firestore_datasource.dart';
import '../models/transaction_dto.dart';
import '../security/description_cipher.dart';

/// Implementação de [TransactionRepository] sobre o Firestore.
///
/// Recebe os tipos do Firestore do datasource e devolve só entidades de
/// domínio — nenhum `QuerySnapshot` sai daqui.
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._datasource, this._descriptionCipher);

  final TransactionFirestoreDatasource _datasource;
  final DescriptionCipher _descriptionCipher;

  @override
  Stream<List<Transaction>> watchAll(String userId) {
    return _datasource
        .watchByUser(userId)
        .asyncMap(
          (snapshot) => Future.wait(snapshot.docs.map(_fromDoc)),
        );
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
      items: await Future.wait(docs.map(_fromDoc)),
      hasMore: docs.length == pageSize,
      // Sem documentos, mantém o cursor anterior: nada mudou.
      cursor: docs.isEmpty ? after : docs.last,
    );
  }

  @override
  Future<Transaction?> getById(String id) async {
    final doc = await _datasource.getById(id);
    return doc == null ? null : await _fromDoc(doc);
  }

  @override
  Future<void> add(Transaction transaction) {
    return _toMap(transaction).then(_datasource.add);
  }

  @override
  Future<void> update(Transaction transaction) {
    final id = transaction.id;
    if (id == null) {
      throw ArgumentError('Não dá pra atualizar uma transação sem id.');
    }
    return _toMap(transaction).then((data) => _datasource.update(id, data));
  }

  @override
  Future<void> delete(String id) => _datasource.delete(id);

  Future<Transaction> _fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = Map<String, dynamic>.from(doc.data() ?? <String, dynamic>{});
    data['description'] = await _descriptionCipher.decryptDescription(
      data['description'] as String?,
    );
    return TransactionDto.fromMap(doc.id, data);
  }

  Future<Map<String, dynamic>> _toMap(Transaction transaction) async {
    final data = TransactionDto.toMap(transaction);
    data['description'] = await _descriptionCipher.encryptDescription(
      transaction.description,
    );
    return data;
  }
}
