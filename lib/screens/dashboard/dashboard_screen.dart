import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/financial_colors.dart';
import '../../data/firebase/transaction_service.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';

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

enum _DashboardPeriod { week, month, threeMonths, sixMonths, all }

enum _DashboardSection { evolution, categories, recent }

class _DashboardScreenState extends State<DashboardScreen> {
  _DashboardPeriod _selectedPeriod = _DashboardPeriod.month;
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
    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  List<TransactionModel> _filterTransactions(
    List<TransactionModel> transactions,
  ) {
    if (_selectedPeriod == _DashboardPeriod.all) return transactions;

    final now = DateTime.now();
    final start = switch (_selectedPeriod) {
      _DashboardPeriod.week => DateTime(now.year, now.month, now.day - 6),
      _DashboardPeriod.month => DateTime(now.year, now.month),
      _DashboardPeriod.threeMonths => DateTime(now.year, now.month - 2),
      _DashboardPeriod.sixMonths => DateTime(now.year, now.month - 5),
      _DashboardPeriod.all => DateTime(2000),
    };

    return transactions.where((item) => !item.date.isBefore(start)).toList();
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
    final user = context.watch<AuthProvider>().user;
    final colors = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final firstName = user?.displayName?.split(' ')[0] ?? 'Usuário';
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: TransactionService().getUserTransactions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _DashboardMessage(
              message: 'Não foi possível carregar seus dados.',
              icon: Icons.cloud_off_rounded,
            );
          }
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final allTransactions = snapshot.data!.docs
              .map(
                (doc) => TransactionModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();
          final transactions = _filterTransactions(allTransactions);

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
                    _BalanceSummary(transactions: transactions),
                    const SizedBox(height: 20),
                    if (_visibleSections.contains(
                      _DashboardSection.evolution,
                    )) ...[
                      const _SectionTitle(title: 'Entradas x despesas'),
                      const SizedBox(height: 10),
                      _EvolutionChart(
                        transactions: transactions,
                        period: _selectedPeriod,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_visibleSections.contains(
                      _DashboardSection.categories,
                    )) ...[
                      const _SectionTitle(title: 'Despesas por categoria'),
                      const SizedBox(height: 10),
                      _CategoryChart(transactions: transactions),
                      const SizedBox(height: 20),
                    ],
                    if (_visibleSections.contains(
                      _DashboardSection.recent,
                    )) ...[
                      const _SectionTitle(title: 'Movimentações recentes'),
                      const SizedBox(height: 10),
                      _RecentTransactions(transactions: transactions),
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
