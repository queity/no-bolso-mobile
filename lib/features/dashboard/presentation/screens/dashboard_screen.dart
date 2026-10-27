import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/financial_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/entities/dashboard_period.dart';
import '../../domain/entities/dashboard_summary.dart';

part 'dashboard_header.dart';
part 'dashboard_controls.dart';
part 'dashboard_summary.dart';
part 'dashboard_charts.dart';
part 'dashboard_transactions.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _DashboardSection { evolution, categories, recent }

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardPeriod _selectedPeriod = DashboardPeriod.month;
  final Set<_DashboardSection> _visibleSections = {
    _DashboardSection.evolution,
    _DashboardSection.categories,
    _DashboardSection.recent,
  };

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  Future<void> _handleLogout(BuildContext context) async {
    await context.read<AuthProvider>().signOut();
    if (context.mounted) context.go('/login');
  }

  Future<void> _openSectionSettings(BuildContext context) async {
    final selectedSections = {..._visibleSections};
    final result = await showModalBottomSheet<Set<_DashboardSection>>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void toggle(_DashboardSection section) {
            setSheetState(() {
              if (selectedSections.contains(section)) {
                selectedSections.remove(section);
              } else {
                selectedSections.add(section);
              }
            });
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personalizar dashboard',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text('Escolha o que deseja acompanhar na tela.'),
                      const SizedBox(height: 8),
                      _SectionCheckbox(
                        icon: Icons.bar_chart_rounded,
                        title: 'Entradas x despesas',
                        value: selectedSections.contains(
                          _DashboardSection.evolution,
                        ),
                        onChanged: () => toggle(_DashboardSection.evolution),
                      ),
                      _SectionCheckbox(
                        icon: Icons.pie_chart_outline_rounded,
                        title: 'Despesas por categoria',
                        value: selectedSections.contains(
                          _DashboardSection.categories,
                        ),
                        onChanged: () => toggle(_DashboardSection.categories),
                      ),
                      _SectionCheckbox(
                        icon: Icons.receipt_long_rounded,
                        title: 'Movimentações recentes',
                        value: selectedSections.contains(
                          _DashboardSection.recent,
                        ),
                        onChanged: () => toggle(_DashboardSection.recent),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, selectedSections),
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _visibleSections
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // `context.select` em vez de `context.watch`: a tela só reconstrói quando
    // o valor selecionado muda, não a cada notifyListeners dos providers.
    final isAuth = context.select<AuthProvider, bool>((auth) => auth.isAuth);
    final firstName = context.select<AuthProvider, String>(
      (auth) => auth.user?.firstName ?? 'Usuário',
    );
    final isLoading = context.select<TransactionsProvider, bool>(
      (provider) => provider.isLoading,
    );
    final hasError = context.select<TransactionsProvider, bool>(
      (provider) => provider.hasError,
    );
    // O provider devolve a mesma instância enquanto os dados e o período não
    // mudam, então trocar de aba e voltar não recalcula nada.
    final summary = context.select<TransactionsProvider, DashboardSummary>(
      (provider) => provider.summaryFor(_selectedPeriod),
    );
    final colors = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    if (!isAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: Builder(
        builder: (context) {
          if (hasError) {
            return _DashboardMessage(
              message: 'Não foi possível carregar seus dados.',
              icon: Icons.cloud_off_rounded,
              onRetry: context.read<TransactionsProvider>().retry,
            );
          }
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _DashboardHeader(
                  firstName: firstName,
                  greeting: _greeting,
                  topPadding: topPadding,
                  onLogout: () => _handleLogout(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _PeriodSelector(
                      selectedPeriod: _selectedPeriod,
                      onChanged: (period) =>
                          setState(() => _selectedPeriod = period),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _openSectionSettings(context),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Personalizar dashboard'),
                    ),
                    const SizedBox(height: 16),
                    _BalanceSummary(summary: summary),
                    const SizedBox(height: 20),
                    if (_visibleSections.contains(
                      _DashboardSection.evolution,
                    )) ...[
                      const _SectionTitle(title: 'Entradas x despesas'),
                      const SizedBox(height: 10),
                      _EvolutionChart(summary: summary),
                      const SizedBox(height: 20),
                    ],
                    if (_visibleSections.contains(
                      _DashboardSection.categories,
                    )) ...[
                      const _SectionTitle(title: 'Despesas por categoria'),
                      const SizedBox(height: 10),
                      _CategoryChart(totals: summary.expensesByCategory),
                      const SizedBox(height: 20),
                    ],
                    if (_visibleSections.contains(
                      _DashboardSection.recent,
                    )) ...[
                      const _SectionTitle(title: 'Movimentações recentes'),
                      const SizedBox(height: 10),
                      _RecentTransactions(transactions: summary.recent),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
