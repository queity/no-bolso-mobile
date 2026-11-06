import 'transaction.dart';

/// Critérios da listagem de transações: categoria, período e busca por
/// descrição.
///
/// Dart puro, como o resto do domínio. A filtragem acontece em memória, sobre
/// a lista que já chega em tempo real pelo stream do repositório — o
/// Firestore não sabe buscar "contém" num texto, então a busca por descrição
/// não tem como ir para o servidor.
///
/// Usa `DateTime` puro em vez do `DateTimeRange` do Flutter pra manter o
/// domínio livre de dependências de UI — a tela faz a conversão.
class TransactionFilter {
  const TransactionFilter({
    this.category,
    this.startDate,
    this.endDate,
    this.query = '',
  });

  final TransactionCategory? category;

  /// Início do período (inclusivo). Só a data importa.
  final DateTime? startDate;

  /// Fim do período (inclusivo). Só a data importa: o dia inteiro entra.
  final DateTime? endDate;

  /// Texto buscado na descrição, do jeito que o usuário digitou. A
  /// normalização (maiúsculas, acentos, espaços) acontece na comparação.
  final String query;

  bool get hasDateRange => startDate != null && endDate != null;
  bool get hasQuery => normalize(query).isNotEmpty;

  /// `true` quando nenhum critério está ativo — a lista passa inteira.
  bool get isEmpty => category == null && !hasDateRange && !hasQuery;

  /// Aplica o filtro a [transactions], mantendo a ordem original.
  ///
  /// Prefira este método a chamar [matches] item a item: a busca é
  /// normalizada uma vez só, e não uma vez por transação.
  List<Transaction> apply(List<Transaction> transactions) {
    if (isEmpty) return transactions;
    final terms = _terms(query);
    return [
      for (final t in transactions)
        if (_matches(t, terms)) t,
    ];
  }

  /// Diz se [transaction] passa por todos os critérios ativos.
  bool matches(Transaction transaction) =>
      _matches(transaction, _terms(query));

  bool _matches(Transaction t, List<String> terms) {
    if (category != null && t.category != category) return false;

    if (hasDateRange) {
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      // O fim vem do date picker com 00:00 — sem isso, as transações do
      // próprio último dia ficariam de fora.
      final end = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
        23,
        59,
        59,
        999,
      );
      if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
    }

    if (terms.isNotEmpty) {
      final description = normalize(t.description ?? '');
      if (description.isEmpty) return false;
      // Cada palavra buscada precisa aparecer, em qualquer ordem:
      // "restaurante almoço" encontra "Almoço no restaurante".
      for (final term in terms) {
        if (!description.contains(term)) return false;
      }
    }

    return true;
  }

  static List<String> _terms(String query) {
    final normalized = normalize(query);
    return normalized.isEmpty ? const [] : normalized.split(' ');
  }

  /// Deixa o texto pronto para comparação: minúsculas, sem acentos e com os
  /// espaços repetidos reduzidos a um só. "  Almoço  NO Café " vira
  /// "almoco no cafe".
  ///
  /// Também é usado pelo provider da listagem para descartar buscas
  /// equivalentes (`distinct`) antes de filtrar.
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_withoutAccent[char] ?? char);
    }
    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static const _withoutAccent = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
}
