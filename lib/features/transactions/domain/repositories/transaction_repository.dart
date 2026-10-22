import '../entities/transaction.dart';
import '../entities/transaction_page.dart';

/// Contrato de acesso às transações.
///
/// As telas (e, na etapa 2, o `TransactionsProvider`) dependem só desta
/// interface — a implementação com Firestore fica em
/// `data/repositories/transaction_repository_impl.dart`. Nos testes, basta
/// uma implementação fake em memória.
abstract interface class TransactionRepository {
  /// Todas as transações do usuário, mais nova primeiro, em tempo real.
  Stream<List<Transaction>> watchAll(String userId);

  /// Uma página da listagem, com filtros. Passe o [TransactionPage.cursor]
  /// da página anterior em [after] para buscar a seguinte.
  Future<TransactionPage> getPage({
    required String userId,
    int pageSize = 20,
    Object? after,
    TransactionFilter filter = const TransactionFilter(),
  });

  /// Busca uma transação pelo id. `null` quando ela não existe mais.
  Future<Transaction?> getById(String id);

  Future<void> add(Transaction transaction);

  /// Atualiza uma transação existente — [Transaction.id] é obrigatório.
  Future<void> update(Transaction transaction);

  Future<void> delete(String id);
}
