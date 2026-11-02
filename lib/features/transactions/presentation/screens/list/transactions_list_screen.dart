import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/financial_colors.dart';
import '../../../domain/entities/transaction.dart';
import '../../providers/transaction_list_provider.dart';
import '../../providers/transactions_provider.dart';

/// Listagem de transações do usuário logado.
///
/// Busca, filtros e quantos itens mostrar ficam no [TransactionListProvider]
/// (reativo, com rxdart); carregando e erro vêm do [TransactionsProvider].
/// Esta tela só desenha e repassa as ações. A lista se atualiza sozinha
/// quando uma transação é criada, editada ou excluída — não precisa
/// recarregar ao voltar do formulário.
class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Texto do campo de busca. É da tela (o provider só recebe cada tecla),
  /// por isso o "Limpar" precisa zerar os dois.
  final TextEditingController _searchController = TextEditingController();

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  TransactionListProvider get _list => context.read<TransactionListProvider>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final list = _list;
    if (!list.hasMore) return;

    // Mostra mais itens um pouco antes do fim do scroll. Os dados já estão
    // em memória, então é instantâneo e não tem como falhar.
    const threshold = 300.0;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - threshold) {
      list.loadMore();
    }
  }

  void _clearFilters() {
    _searchController.clear();
    _list.clearFilters();
  }

  Future<void> _pickDateRange() async {
    final list = _list;
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      // Mesmos limites do date picker do formulário (`_pickDate`): sem
      // datas futuras, começando em 2000.
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: list.hasDateRange
          ? DateTimeRange(start: list.startDate!, end: list.endDate!)
          : null,
    );

    if (selected == null || !mounted) return;
    list.setDateRange(selected.start, selected.end);
  }

  Future<void> _openCategoryPicker() async {
    final list = _list;
    final result = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (context) => _CategoryPickerSheet(selected: list.category),
    );

    // Fechar arrastando/tocando fora (sem escolher nada) também devolve
    // `null` do `showModalBottomSheet` — igual ao valor que a categoria
    // usaria se ela própria pudesse ser `null`. Por isso "Todas" pop com um
    // sentinela (`_CategoryPickerSheet.allCategories`) em vez de `null`: só
    // assim dá pra distinguir "usuário confirmou Todas" de "fechou sem
    // escolher" (que deve manter o filtro como estava).
    if (result == null) return;
    if (result == _CategoryPickerSheet.allCategories) {
      list.setCategory(null);
      return;
    }
    list.setCategory(result as TransactionCategory);
  }

  /// Em debug, mostra o erro de verdade (ex.: link do Firestore pra criar um
  /// índice ausente) em vez de só a mensagem genérica. Some em release.
  String _errorMessage(Object error) {
    return kDebugMode
        ? 'Não foi possível carregar as transações.\n\n[debug] $error'
        : 'Não foi possível carregar as transações. Tente de novo.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final list = context.watch<TransactionListProvider>();
    final isLoading = context.select<TransactionsProvider, bool>(
      (provider) => provider.isLoading,
    );
    final error = context.select<TransactionsProvider, Object?>(
      (provider) => provider.error,
    );

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
            _SearchField(
              controller: _searchController,
              onChanged: list.setQuery,
            ),
            _FilterBar(
              selectedCategory: list.category,
              selectedDateRange: list.hasDateRange
                  ? DateTimeRange(start: list.startDate!, end: list.endDate!)
                  : null,
              hasActiveFilters: list.hasActiveFilters,
              onCategoryTap: _openCategoryPicker,
              onDateRangeTap: _pickDateRange,
              onClearTap: _clearFilters,
            ),
            Expanded(
              child: _buildBody(list, isLoading: isLoading, error: error),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(
    TransactionListProvider list, {
    required bool isLoading,
    required Object? error,
  }) {
    final transactions = list.items;

    // Só troca a lista pelo carregando/erro quando não há nada pra mostrar
    // (primeira carga, troca de usuário). Num "puxar para atualizar", o que
    // já estava na tela continua lá.
    if (isLoading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && transactions.isEmpty) {
      return _ErrorState(
        message: _errorMessage(error),
        onRetry: context.read<TransactionsProvider>().retry,
      );
    }

    if (transactions.isEmpty) {
      return _EmptyState(
        hasActiveFilters: list.hasActiveFilters,
        query: list.hasQuery ? _searchController.text.trim() : null,
      );
    }

    return RefreshIndicator(
      // Assina o stream de novo; o indicador some quando a resposta chega.
      onRefresh: context.read<TransactionsProvider>().refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
        itemCount: transactions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return _TransactionTile(
            transaction: transaction,
            dateFormat: _dateFormat,
            currencyFormat: _currencyFormat,
            onTap: () => context.push('/transactions/${transaction.id}/edit'),
          );
        },
      ),
    );
  }
}

/// Campo de busca por descrição. Repassa cada tecla ao provider — quem
/// espera o usuário parar de digitar (debounce) é o pipeline rxdart do
/// [TransactionListProvider].
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      // Reconstrói só o campo (não a tela) pra mostrar/esconder o "x".
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar na descrição',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Linha de filtros: chips de categoria/período + limpar, logo abaixo do
/// campo de busca.
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

  final Transaction transaction;
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

/// Mostrado quando o stream de transações falha antes de trazer qualquer
/// dado.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mostrado quando não há nenhuma transação (com ou sem filtro aplicado).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilters, this.query});

  final bool hasActiveFilters;

  /// Texto buscado, como o usuário digitou. Nulo quando não há busca.
  final String? query;

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
              query != null
                  ? 'Nenhuma transação encontrada para "$query".'
                  : hasActiveFilters
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
