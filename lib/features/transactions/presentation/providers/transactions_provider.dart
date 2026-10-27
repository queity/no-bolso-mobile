import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../dashboard/domain/entities/dashboard_period.dart';
import '../../../dashboard/domain/entities/dashboard_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/save_transaction.dart';

/// Estado central das transações do usuário logado.
///
/// - Mantém **uma única** assinatura em tempo real (`watchAll`), trocada só
///   quando o usuário muda. Antes, o Dashboard criava uma assinatura nova no
///   Firestore a cada rebuild.
/// - É por aqui que as telas criam, editam e excluem: a mudança volta pelo
///   stream e atualiza todas as telas que observam este provider.
/// - Calcula os resumos do Dashboard e guarda em memória até os dados
///   mudarem, em vez de recalcular a cada rebuild.
///
/// Fica ligado ao `AuthProvider` por um `ChangeNotifierProxyProvider` (ver
/// `AppDependencies`), que chama [bindUser] quando o usuário loga ou sai.
class TransactionsProvider extends ChangeNotifier {
  /// [clock] permite fixar a data nos testes (os períodos são relativos a
  /// hoje).
  TransactionsProvider(
    this._repository,
    this._saveTransaction, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TransactionRepository _repository;
  final SaveTransaction _saveTransaction;
  final DateTime Function() _clock;

  String? _userId;
  StreamSubscription<List<Transaction>>? _subscription;
  List<Transaction> _transactions = const [];
  bool _isLoading = false;
  Object? _error;
  int _revision = 0;
  bool _disposed = false;

  final Map<DashboardPeriod, DashboardSummary> _summaryCache = {};
  int _summaryCacheRevision = -1;
  DateTime? _summaryCacheDay;

  /// Transações do usuário, mais nova primeiro. Lista imutável.
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  Object? get error => _error;
  String? get userId => _userId;

  /// Muda toda vez que a lista de transações muda. Outros providers (como o
  /// `TransactionListProvider`) usam isso pra saber quando recarregar.
  int get revision => _revision;

  /// Passa a observar as transações de [userId] (ou limpa tudo, quando
  /// `null`). Chamar de novo com o mesmo usuário não faz nada.
  void bindUser(String? userId) {
    if (userId == _userId) return;

    _userId = userId;
    _subscription?.cancel();
    _subscription = null;
    // Ao trocar de usuário, os dados do anterior somem na hora — nunca
    // aparecem na tela de quem logou depois.
    _transactions = const [];
    _error = null;
    _isLoading = userId != null;
    _revision++;

    if (userId != null) _listen(userId);

    // `bindUser` é chamado pelo ProxyProvider durante o build; avisar os
    // ouvintes ali dispara "markNeedsBuild() called during build".
    _notifyLater();
  }

  /// Tenta de novo depois de um erro no stream.
  void retry() {
    final userId = _userId;
    if (userId == null) return;
    _subscription?.cancel();
    _error = null;
    _isLoading = true;
    notifyListeners();
    _listen(userId);
  }

  void _listen(String userId) {
    _subscription = _repository
        .watchAll(userId)
        .listen(
          (items) {
            _transactions = List.unmodifiable(items);
            _isLoading = false;
            _error = null;
            _revision++;
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Erro ao observar transações: $error');
            _isLoading = false;
            _error = error;
            notifyListeners();
          },
        );
  }

  /// Transação já carregada em memória, sem ir ao banco.
  Transaction? findById(String id) {
    for (final t in _transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Usa a cópia em memória quando existe, senão busca no repositório
  /// (ex.: a tela de edição aberta direto por link).
  Future<Transaction?> getById(String id) async {
    return findById(id) ?? await _repository.getById(id);
  }

  /// Cria ou atualiza (ver `SaveTransaction`). Não precisa atualizar nada à
  /// mão depois: a mudança volta pelo stream.
  Future<void> save(
    Transaction transaction, {
    String? newReceiptPath,
    String? previousReceiptUrl,
  }) {
    return _saveTransaction(
      transaction,
      newReceiptPath: newReceiptPath,
      previousReceiptUrl: previousReceiptUrl,
    );
  }

  Future<void> delete(String id) => _repository.delete(id);

  /// Resumo do Dashboard para [period], calculado uma vez e reaproveitado
  /// até as transações mudarem (ou virar o dia, já que os períodos são
  /// relativos a hoje). Como devolve a mesma instância, um
  /// `context.select` sobre ele só reconstrói a tela quando algo mudou.
  DashboardSummary summaryFor(DashboardPeriod period) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    if (_summaryCacheRevision != _revision || _summaryCacheDay != today) {
      _summaryCache.clear();
      _summaryCacheRevision = _revision;
      _summaryCacheDay = today;
    }
    return _summaryCache.putIfAbsent(
      period,
      () => DashboardSummary.calculate(_transactions, period, now),
    );
  }

  void _notifyLater() {
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
