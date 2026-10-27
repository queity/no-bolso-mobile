import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_page.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Estado da listagem paginada de transações (tela "Transações").
///
/// A listagem usa busca por página com filtros (e não o stream em tempo
/// real) pra paginar por cursor no Firestore. Para ela não ficar
/// desatualizada, o `ChangeNotifierProxyProvider2` em `AppDependencies`
/// chama [sync] com a `revision` do `TransactionsProvider`: quando uma
/// transação é criada, editada ou excluída (nesta ou em outra tela, ou em
/// outro aparelho), a primeira página é recarregada sozinha.
class TransactionListProvider extends ChangeNotifier {
  TransactionListProvider(this._repository, {this.pageSize = 20});

  final TransactionRepository _repository;
  final int pageSize;

  String? _userId;
  int? _revision;
  bool _hasLoaded = false;
  bool _disposed = false;

  /// Incrementado a cada nova busca da primeira página. Resposta que chega
  /// com um id antigo (o usuário trocou o filtro no meio) é descartada.
  int _requestId = 0;

  final List<Transaction> _items = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _isLoadingFirstPage = false;
  bool _isLoadingMore = false;
  Object? _error;

  TransactionCategory? _category;
  DateTime? _startDate;
  DateTime? _endDate;

  List<Transaction> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoadingFirstPage => _isLoadingFirstPage;
  bool get isLoadingMore => _isLoadingMore;
  Object? get error => _error;

  TransactionCategory? get category => _category;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool get hasDateRange => _startDate != null && _endDate != null;
  bool get hasActiveFilters => _category != null || hasDateRange;

  TransactionFilter get _filter => TransactionFilter(
    category: _category,
    startDate: _startDate,
    endDate: _endDate,
  );

  /// Chamado pelo ProxyProvider sempre que o usuário ou as transações mudam.
  void sync({required String? userId, required int revision}) {
    if (userId != _userId) {
      _userId = userId;
      _revision = revision;
      _reset();
      // Fora do build: o ProxyProvider chama `sync` enquanto constrói.
      if (userId != null) {
        scheduleMicrotask(loadFirstPage);
      } else {
        scheduleMicrotask(_notifyIfAlive);
      }
      return;
    }

    if (revision != _revision) {
      _revision = revision;
      // Antes da primeira carga não há o que atualizar — ela já vem fresca.
      if (_hasLoaded) scheduleMicrotask(refresh);
    }
  }

  void _reset() {
    _requestId++;
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _hasLoaded = false;
    _error = null;
    _isLoadingMore = false;
    _isLoadingFirstPage = _userId != null;
    _category = null;
    _startDate = null;
    _endDate = null;
  }

  /// Carrega a primeira página do zero, mostrando o carregamento.
  Future<void> loadFirstPage() => _loadFirstPage(showSpinner: true);

  /// Recarrega a primeira página sem esconder a lista atual (usado no
  /// "puxar para atualizar" e quando os dados mudam).
  Future<void> refresh() => _loadFirstPage(showSpinner: false);

  Future<void> _loadFirstPage({required bool showSpinner}) async {
    final userId = _userId;
    if (userId == null || _disposed) return;

    final requestId = ++_requestId;
    if (showSpinner) _isLoadingFirstPage = true;
    _isLoadingMore = false;
    _error = null;
    notifyListeners();

    try {
      final page = await _repository.getPage(
        userId: userId,
        pageSize: pageSize,
        filter: _filter,
      );
      if (_disposed || requestId != _requestId) return;

      _items
        ..clear()
        ..addAll(page.items);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _hasLoaded = true;
    } catch (e) {
      if (_disposed || requestId != _requestId) return;
      debugPrint('Erro ao carregar transações: $e');
      // Numa atualização silenciosa, mantém o que já estava na tela.
      if (showSpinner || _items.isEmpty) _error = e;
    }

    _isLoadingFirstPage = false;
    notifyListeners();
  }

  /// Busca a próxima página. Lança o erro, pra tela avisar o usuário — a
  /// lista que já estava carregada continua intacta.
  Future<void> loadNextPage() async {
    final userId = _userId;
    if (userId == null ||
        !_hasMore ||
        _isLoadingMore ||
        _isLoadingFirstPage ||
        _cursor == null) {
      return;
    }

    final requestId = _requestId;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repository.getPage(
        userId: userId,
        pageSize: pageSize,
        after: _cursor,
        filter: _filter,
      );
      if (_disposed || requestId != _requestId) return;

      _items.addAll(page.items);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      if (_disposed || requestId != _requestId) return;
      _isLoadingMore = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setCategory(TransactionCategory? category) {
    _category = category;
    return loadFirstPage();
  }

  Future<void> setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    return loadFirstPage();
  }

  Future<void> clearFilters() {
    _category = null;
    _startDate = null;
    _endDate = null;
    return loadFirstPage();
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
