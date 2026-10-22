import 'transaction.dart';

/// Filtros opcionais da listagem paginada.
///
/// Usa `DateTime` puro em vez do `DateTimeRange` do Flutter pra manter o
/// domínio livre de dependências de UI — a tela faz a conversão.
class TransactionFilter {
  const TransactionFilter({this.category, this.startDate, this.endDate});

  final TransactionCategory? category;

  /// Início do período (inclusivo).
  final DateTime? startDate;

  /// Fim do período. Só a data importa: o dia inteiro é incluído.
  final DateTime? endDate;

  bool get hasDateRange => startDate != null && endDate != null;
}

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
