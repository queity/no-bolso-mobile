import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_filter.dart';

/// Estado da listagem de transações (tela "Transações"), montado de forma
/// reativa com rxdart.
///
/// Três fontes viram um único resultado com `Rx.combineLatest3`:
///
/// ```
/// transações (stream do TransactionsProvider) ─┐
/// busca  ── debounce 300ms · normalize · distinct ├─► filtro.apply ─► items
/// filtros (categoria + período, na hora)        ─┘
/// ```
///
/// - Qualquer uma das três mudando refaz o filtro: uma transação criada ou
///   editada em outra tela (ou outro aparelho) aparece aqui já filtrada,
///   sem recarregar nada.
/// - A busca espera o usuário parar de digitar ([searchDebounce]) — exceto
///   quando ele apaga tudo, que volta a lista na hora.
/// - A filtragem é em memória: o Firestore não sabe buscar "contém" num
///   texto, e as transações já estão carregadas para o Dashboard.
///
/// Carregando, erro e "tentar de novo" vêm do `TransactionsProvider` — esta
/// classe só cuida de busca, filtros e de quantos itens mostrar.
class TransactionListProvider extends ChangeNotifier {
  TransactionListProvider(
    Stream<List<Transaction>> transactions, {
    this.pageSize = 20,
    this.searchDebounce = const Duration(milliseconds: 300),
  }) {
    final query = _queryInput.stream
        // Digitar espera a pausa; apagar a busca volta a lista na hora. Para
        // a busca vazia a janela é um `Stream.value`, não um timer de zero:
        // um timer, mesmo de zero, ainda seria um timer pendente.
        .debounce(
          (text) => TransactionFilter.normalize(text).isEmpty
              ? Stream<void>.value(null)
              : TimerStream<void>(null, searchDebounce),
        )
        .map(TransactionFilter.normalize)
        // `combineLatest` só emite depois que TODAS as fontes emitiram uma
        // vez. Sem isso, a lista ficaria vazia até o usuário digitar algo.
        .startWith('')
        // "Almoço", "almoco " e "ALMOÇO" são a mesma busca: não refaz nada.
        .distinct();

    _subscription =
        Rx.combineLatest3<
              List<Transaction>,
              String,
              TransactionFilter,
              _ListResult
            >(
              transactions,
              query,
              _filters,
              (items, query, filters) => _ListResult(
                query: query,
                filters: filters,
                results: TransactionFilter(
                  category: filters.category,
                  startDate: filters.startDate,
                  endDate: filters.endDate,
                  query: query,
                ).apply(items),
              ),
            )
            .listen(_onResult);
  }

  /// Quantos itens aparecem a cada "página" da rolagem infinita.
  final int pageSize;

  /// Pausa na digitação antes de aplicar a busca.
  final Duration searchDebounce;

  /// O texto da busca, do jeito que chega do campo (a cada tecla).
  final _queryInput = PublishSubject<String>();

  /// Categoria e período. Começa sem filtro para o `combineLatest` já ter um
  /// valor. O campo `query` daqui não é usado — a busca tem fonte própria.
  final _filters = BehaviorSubject<TransactionFilter>.seeded(
    const TransactionFilter(),
  );

  late final StreamSubscription<_ListResult> _subscription;

  String? _userId;
  bool _disposed = false;

  List<Transaction> _results = const [];
  List<Transaction> _visible = const [];
  String _appliedQuery = '';
  TransactionFilter? _lastFilters;
  int _visibleCount = 0;

  /// Itens visíveis agora (os primeiros [pageSize], aumentando com
  /// [loadMore]).
  List<Transaction> get items => _visible;

  /// Quantas transações passam pelos filtros, contando as ainda não
  /// mostradas.
  int get resultCount => _results.length;
  bool get hasMore => _results.length > _visibleCount;

  /// Busca efetivamente aplicada (já normalizada, depois do debounce).
  String get appliedQuery => _appliedQuery;
  bool get hasQuery => _appliedQuery.isNotEmpty;

  TransactionCategory? get category => _filters.value.category;
  DateTime? get startDate => _filters.value.startDate;
  DateTime? get endDate => _filters.value.endDate;
  bool get hasDateRange => _filters.value.hasDateRange;
  bool get hasActiveFilters => category != null || hasDateRange || hasQuery;

  /// Chamado pelo ProxyProvider quando a sessão muda. Trocar de usuário
  /// zera busca e filtros — os de um não podem aparecer para o outro.
  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    if (_disposed) return;
    _visibleCount = pageSize;
    // Os subjects entregam os eventos de forma assíncrona, então isto é
    // seguro mesmo sendo chamado durante o build do ProxyProvider.
    _queryInput.add('');
    _filters.add(const TransactionFilter());
  }

  /// Recebe o texto do campo de busca a cada tecla.
  void setQuery(String text) {
    if (!_disposed) _queryInput.add(text);
  }

  void setCategory(TransactionCategory? category) {
    final current = _filters.value;
    _setFilters(
      TransactionFilter(
        category: category,
        startDate: current.startDate,
        endDate: current.endDate,
      ),
    );
  }

  void setDateRange(DateTime start, DateTime end) {
    _setFilters(
      TransactionFilter(
        category: _filters.value.category,
        startDate: start,
        endDate: end,
      ),
    );
  }

  /// Limpa categoria, período e busca. O texto do campo de busca é da tela —
  /// ela precisa limpar o controller também.
  void clearFilters() {
    if (_disposed) return;
    _queryInput.add('');
    _setFilters(const TransactionFilter());
  }

  /// Mostra mais [pageSize] itens (rolagem infinita). Síncrono e sem erro
  /// possível: os dados já estão em memória.
  void loadMore() {
    if (!hasMore || _disposed) return;
    _visibleCount += pageSize;
    _updateVisible();
    notifyListeners();
  }

  void _setFilters(TransactionFilter filters) {
    if (!_disposed) _filters.add(filters);
  }

  void _onResult(_ListResult result) {
    // Mudou a busca ou os filtros: a rolagem recomeça do topo. Se só os
    // dados mudaram (transação nova), mantém quantos itens já estavam
    // visíveis.
    if (result.query != _appliedQuery ||
        !identical(result.filters, _lastFilters)) {
      _visibleCount = pageSize;
    }
    _results = result.results;
    _appliedQuery = result.query;
    _lastFilters = result.filters;
    _updateVisible();
    if (!_disposed) notifyListeners();
  }

  void _updateVisible() {
    _visible = _results.length <= _visibleCount
        ? _results
        : List.unmodifiable(_results.take(_visibleCount));
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _queryInput.close();
    _filters.close();
    super.dispose();
  }
}

/// Uma saída do `combineLatest`: o resultado e os critérios que o geraram.
class _ListResult {
  const _ListResult({
    required this.query,
    required this.filters,
    required this.results,
  });

  final String query;
  final TransactionFilter filters;
  final List<Transaction> results;
}
