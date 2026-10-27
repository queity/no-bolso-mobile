import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/dashboard/domain/entities/dashboard_period.dart';
import 'package:no_bolso_mobile/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';

import '../../../helpers/transaction_builders.dart';

void main() {
  final now = DateTime(2026, 10, 26, 15);

  test('soma entradas, despesas e saldo só do período', () {
    final summary = DashboardSummary.calculate(
      [
        buildTx(amount: 100, income: true, date: DateTime(2026, 10, 20)),
        buildTx(amount: 30, date: DateTime(2026, 10, 5)),
        // Mês anterior: fora de "1 mês".
        buildTx(amount: 999, date: DateTime(2026, 9, 30)),
      ],
      DashboardPeriod.month,
      now,
    );

    expect(summary.income, 100);
    expect(summary.expenses, 30);
    expect(summary.balance, 70);
  });

  test('"Todos" não filtra por data', () {
    final summary = DashboardSummary.calculate(
      [buildTx(amount: 5, date: DateTime(2001, 1, 1))],
      DashboardPeriod.all,
      now,
    );

    expect(summary.expenses, 5);
  });

  test('despesas por categoria: ordena e agrupa sem categoria em Outros', () {
    final summary = DashboardSummary.calculate(
      [
        buildTx(amount: 12, category: TransactionCategory.lazer),
        buildTx(amount: 50, category: TransactionCategory.casa),
        buildTx(amount: 5),
        buildTx(amount: 5, category: TransactionCategory.outros),
        // Entrada não entra no gráfico de despesas.
        buildTx(amount: 500, income: true, category: TransactionCategory.receitasFixas),
      ],
      DashboardPeriod.month,
      now,
    );

    expect(
      summary.expensesByCategory.map((c) => (c.category, c.total)),
      [
        (TransactionCategory.casa, 50.0),
        (TransactionCategory.lazer, 12.0),
        (TransactionCategory.outros, 10.0),
      ],
    );
  });

  test('semanal: 7 barras diárias terminando hoje', () {
    final summary = DashboardSummary.calculate(
      [
        buildTx(amount: 8, date: DateTime(2026, 10, 26, 9)),
        buildTx(amount: 3, date: DateTime(2026, 10, 20)),
      ],
      DashboardPeriod.week,
      now,
    );

    expect(summary.granularity, EvolutionGranularity.daily);
    expect(summary.evolution, hasLength(7));
    expect(summary.evolution.first.start, DateTime(2026, 10, 20));
    expect(summary.evolution.first.expenses, 3);
    expect(summary.evolution.last.start, DateTime(2026, 10, 26));
    expect(summary.evolution.last.expenses, 8);
    expect(summary.evolutionMax, 8);
  });

  test('1 mês: blocos de 7 dias, o último até o fim do mês', () {
    final october = DashboardSummary.calculate(
      [buildTx(amount: 4, date: DateTime(2026, 10, 31))],
      DashboardPeriod.month,
      now,
    );
    expect(
      october.evolution.map((b) => '${b.start.day}-${b.end.day}'),
      ['1-7', '8-14', '15-21', '22-28', '29-31'],
    );
    expect(october.evolution.last.expenses, 4);

    // Fevereiro de 2026 tem 28 dias: 4 barras, sem um "29-28".
    final february = DashboardSummary.calculate(
      const [],
      DashboardPeriod.month,
      DateTime(2026, 2, 10),
    );
    expect(february.evolution, hasLength(4));
  });

  test('3 e 6 meses: uma barra por mês', () {
    final three = DashboardSummary.calculate(const [], DashboardPeriod.threeMonths, now);
    final six = DashboardSummary.calculate(const [], DashboardPeriod.sixMonths, now);

    expect(three.evolution.map((b) => b.start.month), [8, 9, 10]);
    expect(six.evolution, hasLength(6));
    expect(six.evolution.first.start, DateTime(2026, 5));
    expect(six.evolution.first.end, DateTime(2026, 5, 31));
  });

  test('recentes: no máximo 5, na ordem recebida', () {
    final items = [
      for (var i = 0; i < 8; i++) buildTx(id: '$i', date: DateTime(2026, 10, 20 - i)),
    ];
    final summary = DashboardSummary.calculate(items, DashboardPeriod.month, now);

    expect(summary.recent.map((t) => t.id), ['0', '1', '2', '3', '4']);
  });
}
