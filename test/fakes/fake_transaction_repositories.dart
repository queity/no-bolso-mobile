import 'dart:async';

import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction_page.dart';
import 'package:no_bolso_mobile/features/transactions/domain/repositories/receipt_repository.dart';
import 'package:no_bolso_mobile/features/transactions/domain/repositories/transaction_repository.dart';

/// [TransactionRepository] em memória para testes.
///
/// - [emit] / [emitError] simulam o stream em tempo real do `watchAll`.
/// - [pages] é a fila de respostas do `getPage` (vazia = página vazia), e
///   [pageCalls] registra os parâmetros de cada chamada.
class FakeTransactionRepository implements TransactionRepository {
  final List<Transaction> added = [];
  final List<Transaction> updated = [];
  final List<String> deleted = [];

  final List<String> watchedUserIds = [];
  StreamController<List<Transaction>>? _watchController;

  final List<TransactionPage> pages = [];
  final List<({String userId, Object? after, TransactionFilter filter})>
  pageCalls = [];

  final Map<String, Transaction> byId = {};
  int getByIdCalls = 0;

  void emit(List<Transaction> items) => _watchController!.add(items);
  void emitError(Object error) => _watchController!.addError(error);

  @override
  Future<void> add(Transaction transaction) async => added.add(transaction);

  @override
  Future<void> update(Transaction transaction) async =>
      updated.add(transaction);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<Transaction?> getById(String id) async {
    getByIdCalls++;
    return byId[id];
  }

  @override
  Future<TransactionPage> getPage({
    required String userId,
    int pageSize = 20,
    Object? after,
    TransactionFilter filter = const TransactionFilter(),
  }) async {
    pageCalls.add((userId: userId, after: after, filter: filter));
    if (pages.isEmpty) return const TransactionPage(items: [], hasMore: false);
    return pages.removeAt(0);
  }

  @override
  Stream<List<Transaction>> watchAll(String userId) {
    watchedUserIds.add(userId);
    _watchController?.close();
    _watchController = StreamController<List<Transaction>>();
    return _watchController!.stream;
  }
}

/// [ReceiptRepository] em memória. Guarda o que foi enviado e apagado, e
/// pode simular falha no upload com [failUpload].
class FakeReceiptRepository implements ReceiptRepository {
  FakeReceiptRepository({this.failUpload = false});

  final bool failUpload;
  final List<String> uploaded = [];
  final List<String> deleted = [];

  @override
  Future<String> upload({required String filePath, required String userId}) async {
    if (failUpload) throw Exception('upload falhou');
    uploaded.add(filePath);
    return 'https://fake/$userId/${uploaded.length}.jpg';
  }

  @override
  Future<void> delete(String url) async => deleted.add(url);
}
