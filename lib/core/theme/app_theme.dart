import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'financial_colors.dart';

/// Temas (claro/escuro) do app. Plugados no `MaterialApp` via
/// `theme: AppTheme.light` / `darkTheme: AppTheme.dark`.
abstract class AppTheme {
  static ThemeData get light {
    // O `primary` derivado automaticamente pelo ColorScheme.fromSeed fica
    // desaturado demais para texto (ex.: TextButton). Fixamos ele na cor de
    // marca de verdade pra ficar mais legível/evidente.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
    ).copyWith(primary: AppColors.seed);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [FinancialColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        // Campo *filled* pede `UnderlineInputBorder`: o rotulo flutuante fica
        // DENTRO do campo. Com `OutlineInputBorder` ele sobe pra cima da linha
        // da borda (que aqui e invisivel), e o texto ficava pendurado na quina.
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    ).copyWith(primary: AppColors.incomeDark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [FinancialColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        // Campo *filled* pede `UnderlineInputBorder`: o rotulo flutuante fica
        // DENTRO do campo. Com `OutlineInputBorder` ele sobe pra cima da linha
        // da borda (que aqui e invisivel), e o texto ficava pendurado na quina.
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
