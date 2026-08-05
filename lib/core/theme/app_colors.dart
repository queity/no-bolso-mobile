import 'package:flutter/material.dart';

/// Paleta de cores base do app.
///
/// Cores de marca ficam aqui centralizadas. Evite usar `Colors.xxx` direto
/// nas telas — prefira `Theme.of(context).colorScheme` (Material 3) ou
/// `Theme.of(context).extension<FinancialColors>()` para as cores
/// semânticas de receita/despesa.
abstract class AppColors {
  /// Cor semente usada para gerar toda a paleta Material 3 (light/dark).
  static const seed = Color(0xFF2E7D32);

  // Cores semânticas — tema claro.
  static const income = Color(0xFF2E7D32);
  static const incomeContainer = Color(0xFFC8E6C9);
  static const expense = Color(0xFFC62828);
  static const expenseContainer = Color(0xFFFFCDD2);

  // Cores semânticas — tema escuro.
  static const incomeDark = Color(0xFF81C784);
  static const incomeContainerDark = Color(0xFF1B5E20);
  static const expenseDark = Color(0xFFE57373);
  static const expenseContainerDark = Color(0xFFB71C1C);
}
