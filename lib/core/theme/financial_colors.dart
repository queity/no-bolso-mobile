import 'package:flutter/material.dart';

import 'app_colors.dart';

/// [ThemeExtension] com cores que não existem no [ColorScheme] padrão do
/// Material, mas que são recorrentes num app financeiro (receita/despesa).
///
/// Uso:
/// ```dart
/// final financial = Theme.of(context).extension<FinancialColors>()!;
/// Text('+ R\$ 100,00', style: TextStyle(color: financial.income));
/// ```
@immutable
class FinancialColors extends ThemeExtension<FinancialColors> {
  const FinancialColors({
    required this.income,
    required this.incomeContainer,
    required this.expense,
    required this.expenseContainer,
  });

  final Color income;
  final Color incomeContainer;
  final Color expense;
  final Color expenseContainer;

  static const light = FinancialColors(
    income: AppColors.income,
    incomeContainer: AppColors.incomeContainer,
    expense: AppColors.expense,
    expenseContainer: AppColors.expenseContainer,
  );

  static const dark = FinancialColors(
    income: AppColors.incomeDark,
    incomeContainer: AppColors.incomeContainerDark,
    expense: AppColors.expenseDark,
    expenseContainer: AppColors.expenseContainerDark,
  );

  @override
  FinancialColors copyWith({
    Color? income,
    Color? incomeContainer,
    Color? expense,
    Color? expenseContainer,
  }) {
    return FinancialColors(
      income: income ?? this.income,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      expense: expense ?? this.expense,
      expenseContainer: expenseContainer ?? this.expenseContainer,
    );
  }

  @override
  FinancialColors lerp(ThemeExtension<FinancialColors>? other, double t) {
    if (other is! FinancialColors) return this;
    return FinancialColors(
      income: Color.lerp(income, other.income, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseContainer: Color.lerp(
        expenseContainer,
        other.expenseContainer,
        t,
      )!,
    );
  }
}
