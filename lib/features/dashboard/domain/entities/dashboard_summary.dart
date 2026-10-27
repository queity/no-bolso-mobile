import '../../../transactions/domain/entities/transaction.dart';
import 'dashboard_period.dart';

/// Como as barras do gráfico de evolução são agrupadas.
enum EvolutionGranularity { daily, weekOfMonth, monthly }

/// Uma barra do gráfico "Entradas x despesas": totais entre [start] e [end]
/// (ambos inclusivos, só a data importa).
class EvolutionBucket {
  const EvolutionBucket({
    required this.start,
    required this.end,
    required this.income,
    required this.expenses,
  });

  final DateTime start;
  final DateTime end;
  final double income;
  final double expenses;
}

/// Total de despesas de uma categoria no período.
class CategoryTotal {
  const CategoryTotal(this.category, this.total);

  final TransactionCategory category;
  final double total;
}

/// Tudo o que o Dashboard mostra, já calculado para um período.
///
/// Dart puro e sem estado: dá pra testar só com uma lista de transações e
/// uma data fixa. Quem guarda o resultado em memória (pra não recalcular a
/// cada rebuild) é o `TransactionsProvider`.
class DashboardSummary {
  const DashboardSummary._({
    required this.period,
    required this.income,
    required this.expenses,
    required this.granularity,
    required this.evolution,
    required this.evolutionMax,
    required this.expensesByCategory,
    required this.recent,
  });

  /// Quantas movimentações recentes o Dashboard lista.
  static const recentLimit = 5;

  final DashboardPeriod period;
  final double income;
  final double expenses;
  double get balance => income - expenses;

  final EvolutionGranularity granularity;
  final List<EvolutionBucket> evolution;

  /// Maior valor (entrada ou despesa) entre as barras — escala do gráfico.
  final double evolutionMax;

  /// Despesas por categoria, da maior para a menor. Despesa sem categoria
  /// conta como "Outros".
  final List<CategoryTotal> expensesByCategory;

  /// As últimas movimentações do período, mais nova primeiro.
  final List<Transaction> recent;

  /// [transactions] deve vir ordenada da mais nova para a mais antiga (é a
  /// ordem que o repositório devolve).
  factory DashboardSummary.calculate(
    List<Transaction> transactions,
    DashboardPeriod period,
    DateTime now,
  ) {
    final start = period.startFrom(now);
    final inPeriod = start == null
        ? transactions
        : transactions.where((t) => !t.date.isBefore(start)).toList();

    var income = 0.0;
    var expenses = 0.0;
    final byCategory = <TransactionCategory, double>{};
    for (final t in inPeriod) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expenses += t.amount;
        final category = t.category ?? TransactionCategory.outros;
        byCategory[category] = (byCategory[category] ?? 0) + t.amount;
      }
    }

    final categoryTotals = [
      for (final entry in byCategory.entries) CategoryTotal(entry.key, entry.value),
    ]..sort((a, b) => b.total.compareTo(a.total));

    final granularity = switch (period) {
      DashboardPeriod.week => EvolutionGranularity.daily,
      DashboardPeriod.month => EvolutionGranularity.weekOfMonth,
      _ => EvolutionGranularity.monthly,
    };

    final evolution = [
      for (final (bucketStart, bucketEnd) in _bucketRanges(period, now))
        _sumBucket(inPeriod, bucketStart, bucketEnd),
    ];
    var evolutionMax = 0.0;
    for (final bucket in evolution) {
      if (bucket.income > evolutionMax) evolutionMax = bucket.income;
      if (bucket.expenses > evolutionMax) evolutionMax = bucket.expenses;
    }

    return DashboardSummary._(
      period: period,
      income: income,
      expenses: expenses,
      granularity: granularity,
      evolution: List.unmodifiable(evolution),
      evolutionMax: evolutionMax,
      expensesByCategory: List.unmodifiable(categoryTotals),
      recent: List.unmodifiable(inPeriod.take(recentLimit)),
    );
  }

  /// Intervalos (início, fim) de cada barra do gráfico de evolução.
  static List<(DateTime, DateTime)> _bucketRanges(
    DashboardPeriod period,
    DateTime now,
  ) {
    switch (period) {
      case DashboardPeriod.week:
        // Os últimos 7 dias, um por barra.
        return [
          for (var i = 0; i < 7; i++)
            (
              DateTime(now.year, now.month, now.day - 6 + i),
              DateTime(now.year, now.month, now.day - 6 + i),
            ),
        ];
      case DashboardPeriod.month:
        // Blocos de 7 dias do mês atual (1-7, 8-14, ...). O último bloco vai
        // até o fim do mês, então fevereiro sem dia 29 fica com 4 barras.
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        return [
          for (var first = 1; first <= lastDay; first += 7)
            (
              DateTime(now.year, now.month, first),
              DateTime(
                now.year,
                now.month,
                first + 6 > lastDay ? lastDay : first + 6,
              ),
            ),
        ];
      case DashboardPeriod.threeMonths:
      case DashboardPeriod.sixMonths:
      case DashboardPeriod.all:
        // Uma barra por mês. "Todos" mostra os últimos 12 meses.
        final months = switch (period) {
          DashboardPeriod.threeMonths => 3,
          DashboardPeriod.sixMonths => 6,
          _ => 12,
        };
        return [
          for (var i = 0; i < months; i++)
            (
              DateTime(now.year, now.month - months + 1 + i),
              // Dia 0 do mês seguinte = último dia deste mês.
              DateTime(now.year, now.month - months + 2 + i, 0),
            ),
        ];
    }
  }

  static EvolutionBucket _sumBucket(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
  ) {
    var income = 0.0;
    var expenses = 0.0;
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      if (t.isIncome) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }
    return EvolutionBucket(
      start: start,
      end: end,
      income: income,
      expenses: expenses,
    );
  }
}
