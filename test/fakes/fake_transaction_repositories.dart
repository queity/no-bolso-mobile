import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction_page.dart';
import 'package:no_bolso_mobile/features/transactions/domain/repositories/receipt_repository.dart';
import 'package:no_bolso_mobile/features/transactions/domain/repositories/transaction_repository.dart';

/// [TransactionRepository] em memória para testes.
class FakeTransactionRepository implements TransactionRepository {
  final List<Transaction> added = [];
  final List<Transaction> updated = [];
  final List<String> deleted = [];

  @override
  Future<void> add(Transaction transaction) async => added.add(transaction);

  @override
  Future<void> update(Transaction transaction) async =>
      updated.add(transaction);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<Transaction?> getById(String id) async => null;

  @override
  Future<TransactionPage> getPage({
    required String userId,
    int pageSize = 20,
    Object? after,
    TransactionFilter filter = const TransactionFilter(),
  }) async => const TransactionPage(items: [], hasMore: false);

  @override
  Stream<List<Transaction>> watchAll(String userId) => Stream.value(const []);
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
