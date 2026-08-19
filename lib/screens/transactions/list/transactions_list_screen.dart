import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/financial_colors.dart';
import '../../../data/firebase/transaction_service.dart';
import '../../../models/transaction.dart';
import '../../../providers/auth_provider.dart';

/// Listagem de transações do usuário logado.
///
/// Busca por página (`TransactionService.getTransactionsPage`) em vez de
/// tempo real: permite paginar por cursor com filtros de categoria e
/// período. Puxar para atualizar (ou voltar de criar/editar uma transação)
/// recarrega a primeira página do zero.
class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  static const _pageSize = 20;

  final TransactionService _transactionService = TransactionService();
  final ScrollController _scrollController = ScrollController();

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  final List<TransactionModel> _transactions = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = true;

  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  String? _loadError;

  TransactionCategory? _selectedCategory;
  DateTimeRange? _selectedDateRange;

  bool get _hasActiveFilters =>
      _selectedCategory != null || _selectedDateRange != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoadingFirstPage) return;

    // Dispara a próxima página um pouco antes do fim do scroll, pra dar
    // tempo da busca terminar antes do usuário realmente bater no fundo.
    const threshold = 300.0;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - threshold) {
      _loadNextPage();
    }
  }

  String? get _userId => context.read<AuthProvider>().user?.uid;

  Future<void> _loadFirstPage() async {
    final userId = _userId;
    if (userId == null) return;

    setState(() {
      _isLoadingFirstPage = true;
      _loadError = null;
    });

    try {
      final snapshot = await _transactionService.getTransactionsPage(
        userId: userId,
        pageSize: _pageSize,
        category: _selectedCategory,
        dateRange: _selectedDateRange,
      );

      if (!mounted) return;

      setState(() {
        _transactions
          ..clear()
          ..addAll(snapshot.docs.map(TransactionModel.fromDoc));
        _lastDocument = snapshot.docs.isEmpty ? null : snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoadingFirstPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFirstPage = false;
        // Em debug, mostra o erro de verdade (ex.: link do Firestore pra
        // criar um índice ausente) em vez de só a mensagem genérica — é bem
        // mais rápido de diagnosticar do que garimpar no terminal. Some
        // sozinho em release (kDebugMode).
        _loadError = kDebugMode
            ? 'Não foi possível carregar as transações.\n\n[debug] $e'
            : 'Não foi possível carregar as transações. Tente de novo.';
      });
    }
  }

  Future<void> _loadNextPage() async {
    final userId = _userId;
    if (userId == null || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final snapshot = await _transactionService.getTransactionsPage(
        userId: userId,
        pageSize: _pageSize,
        startAfter: _lastDocument,
        category: _selectedCategory,
        dateRange: _selectedDateRange,
      );

      if (!mounted) return;

      setState(() {
        _transactions.addAll(snapshot.docs.map(TransactionModel.fromDoc));
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      // Falha ao carregar mais uma página não derruba a lista que já estava
      // na tela — só avisa e deixa o usuário tentar rolar de novo (ou puxar
      // pra atualizar) em vez de perder o que já tinha carregado.
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar mais transações.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _applyCategory(TransactionCategory? category) async {
    setState(() => _selectedCategory = category);
    await _loadFirstPage();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      // Mesmos limites do date picker do formulário (`_pickDate`): sem
      // datas futuras, começando em 2000.
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _selectedDateRange,
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedDateRange = selected);
    await _loadFirstPage();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedCategory = null;
      _selectedDateRange = null;
    });
    await _loadFirstPage();
  }

  Future<void> _openCategoryPicker() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (context) => _CategoryPickerSheet(selected: _selectedCategory),
    );

    // Fechar arrastando/tocando fora (sem escolher nada) também devolve
    // `null` do `showModalBottomSheet` — igual ao valor que a categoria
    // usaria se ela própria pudesse ser `null`. Por isso "Todas" pop com um
    // sentinela (`_CategoryPickerSheet.allCategories`) em vez de `null`: só
    // assim dá pra distinguir "usuário confirmou Todas" de "fechou sem
    // escolher" (que deve manter o filtro como estava).
    if (result == null) return;
    if (result == _CategoryPickerSheet.allCategories) {
      await _applyCategory(null);
      return;
    }
    await _applyCategory(result as TransactionCategory);
  }

  Future<void> _openTransaction(String route) async {
    // `context.push` retorna um Future que completa quando a tela empurrada
    // é fechada — usado aqui pra recarregar a lista ao voltar de criar ou
    // editar uma transação, sem precisar de um `ChangeNotifier` novo.
    await context.push(route);
    if (mounted) _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transações',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            _FilterBar(
              selectedCategory: _selectedCategory,
              selectedDateRange: _selectedDateRange,
              hasActiveFilters: _hasActiveFilters,
              onCategoryTap: _openCategoryPicker,
              onDateRangeTap: _pickDateRange,
              onClearTap: _clearFilters,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransaction('/transactions/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingFirstPage) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _ErrorState(message: _loadError!, onRetry: _loadFirstPage);
    }

    if (_transactions.isEmpty) {
      return _EmptyState(hasActiveFilters: _hasActiveFilters);
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
        itemCount: _transactions.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _transactions.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final transaction = _transactions[index];
          return _TransactionTile(
            transaction: transaction,
            dateFormat: _dateFormat,
            currencyFormat: _currencyFormat,
            onTap: () =>
                _openTransaction('/transactions/${transaction.id}/edit'),
          );
        },
      ),
    );
  }
}

/// Linha de filtros: chips de categoria/período + limpar, logo abaixo do
/// cabeçalho da tela.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedCategory,
    required this.selectedDateRange,
    required this.hasActiveFilters,
    required this.onCategoryTap,
    required this.onDateRangeTap,
    required this.onClearTap,
  });

  final TransactionCategory? selectedCategory;
  final DateTimeRange? selectedDateRange;
  final bool hasActiveFilters;
  final VoidCallback onCategoryTap;
  final VoidCallback onDateRangeTap;
  final VoidCallback onClearTap;

  String _dateRangeLabel(DateTimeRange range) {
    final format = DateFormat('dd/MM/yy');
    return '${format.format(range.start)} - ${format.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            avatar: const Icon(Icons.local_offer_outlined, size: 18),
            label: Text(selectedCategory?.label ?? 'Categoria'),
            selected: selectedCategory != null,
            onSelected: (_) => onCategoryTap(),
          ),
          FilterChip(
            avatar: const Icon(Icons.event_outlined, size: 18),
            label: Text(
              selectedDateRange != null
                  ? _dateRangeLabel(selectedDateRange!)
                  : 'Período',
            ),
            selected: selectedDateRange != null,
            onSelected: (_) => onDateRangeTap(),
          ),
          if (hasActiveFilters)
            TextButton(onPressed: onClearTap, child: const Text('Limpar')),
        ],
      ),
    );
  }
}

/// Bottom sheet de escolha de categoria, com um chip por
/// [TransactionCategory] mais a opção "Todas".
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.selected});

  final TransactionCategory? selected;

  /// Valor devolvido quando o usuário confirma "Todas" — precisa ser
  /// diferente de `null`, porque fechar o sheet sem escolher nada
  /// (arrastando pra baixo, tocando fora) também devolve `null`.
  static const allCategories = Object();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Categoria',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: selected == null,
                  onSelected: (_) =>
                      Navigator.of(context).pop(_CategoryPickerSheet.allCategories),
                ),
                for (final category in TransactionCategory.values)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: selected == category,
                    onSelected: (_) => Navigator.of(context).pop(category),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma linha da listagem: descrição/categoria, data e valor colorido
/// conforme a direção (mesma convenção de `FinancialColors` do resto do
/// app).
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.dateFormat,
    required this.currencyFormat,
    required this.onTap,
  });

  final TransactionModel transaction;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final financial = Theme.of(context).extension<FinancialColors>()!;

    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? financial.income : financial.expense;
    final amountSign = isIncome ? '+' : '-';

    final title = transaction.description?.trim().isNotEmpty == true
        ? transaction.description!
        : (transaction.category?.label ?? transaction.type.label);

    final subtitleParts = [
      dateFormat.format(transaction.date),
      if (transaction.category != null) transaction.category!.label,
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isIncome
                      ? financial.incomeContainer
                      : financial.expenseContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.savings : Icons.receipt,
                  color: amountColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$amountSign${currencyFormat.format(transaction.amount)}',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostrado quando a busca (primeira página ou "tentar novamente") falha.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => onRetry(),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mostrado quando a busca funcionou mas não há nenhuma transação (com ou
/// sem filtro aplicado).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilters});

  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasActiveFilters
                  ? 'Nenhuma transação encontrada para esse filtro.'
                  : 'Nenhuma transação encontrada.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
