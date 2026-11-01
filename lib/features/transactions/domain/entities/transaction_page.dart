import 'transaction.dart';

// O filtro mudou para o próprio arquivo. O export mantém os imports atuais
// funcionando até a paginação por cursor ser removida.
export 'transaction_filter.dart';

/// Uma página da listagem de transações.
class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<Transaction> items;

  /// `true` quando ainda pode haver mais itens depois desta página.
  final bool hasMore;

  /// Marcador opaco de "onde parei", devolvido ao repositório pra buscar a
  /// próxima página. O domínio não sabe o que tem dentro (no Firestore é o
  /// último `DocumentSnapshot`) — só repassa.
  final Object? cursor;
}
