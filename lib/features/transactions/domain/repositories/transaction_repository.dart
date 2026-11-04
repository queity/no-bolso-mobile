import '../entities/transaction.dart';

/// Contrato de acesso às transações.
///
/// Os providers dependem só desta interface — a implementação com Firestore
/// fica em `data/repositories/transaction_repository_impl.dart`. Nos testes,
/// basta uma implementação fake em memória.
///
/// Não há busca paginada nem filtrada aqui: a listagem filtra em memória
/// sobre o [watchAll] (busca por texto não existe no Firestore), com o
/// `TransactionFilter` do domínio.
abstract interface class TransactionRepository {
  /// Todas as transações do usuário, mais nova primeiro, em tempo real.
  Stream<List<Transaction>> watchAll(String userId);

  /// Busca uma transação pelo id. `null` quando ela não existe mais.
  Future<Transaction?> getById(String id);

  Future<void> add(Transaction transaction);

  /// Atualiza uma transação existente — [Transaction.id] é obrigatório.
  Future<void> update(Transaction transaction);

  Future<void> delete(String id);
}
