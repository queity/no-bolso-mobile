import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';

/// Testes da entidade de domínio.
///
/// Ela é Dart puro: estes testes não sobem Flutter, Firebase nem banco —
/// é exatamente o que a separação de camadas deveria permitir.
void main() {
  Transaction build({
    required double amount,
    required TransactionDirection direction,
  }) {
    return Transaction(
      userId: 'u1',
      amount: amount,
      direction: direction,
      type: TransactionType.pix,
      date: DateTime(2026, 3, 10),
    );
  }

  group('signedAmount', () {
    test('entrada soma', () {
      final t = build(amount: 150, direction: TransactionDirection.entrada);
      expect(t.isIncome, isTrue);
      expect(t.signedAmount, 150);
    });

    test('saída subtrai, mesmo com o valor guardado positivo', () {
      final t = build(amount: 150, direction: TransactionDirection.saida);
      expect(t.isIncome, isFalse);
      expect(t.amount, 150, reason: 'o valor nunca é guardado negativo');
      expect(t.signedAmount, -150);
    });
  });

  group('suggestedDirection da categoria', () {
    test('receitas sugerem entrada', () {
      expect(
        TransactionCategory.receitasFixas.suggestedDirection,
        TransactionDirection.entrada,
      );
      expect(
        TransactionCategory.receitasVariaveis.suggestedDirection,
        TransactionDirection.entrada,
      );
    });

    test('as demais sugerem saída', () {
      expect(
        TransactionCategory.alimentacao.suggestedDirection,
        TransactionDirection.saida,
      );
      expect(
        TransactionCategory.viagem.suggestedDirection,
        TransactionDirection.saida,
      );
    });

    test('"Outros" não sugere nada, porque é ambígua', () {
      expect(TransactionCategory.outros.suggestedDirection, isNull);
    });
  });

  group('códigos legados do No Bolso web', () {
    test('direção, tipo e categoria mantêm os códigos da API antiga', () {
      expect(TransactionDirection.entrada.codigo, 1);
      expect(TransactionDirection.saida.codigo, 2);
      expect(TransactionType.pix.codigo, 1);
      expect(TransactionType.outros.codigo, 5);
      expect(TransactionCategory.alimentacao.codigo, 1);
      expect(TransactionCategory.viagem.codigo, 11);
    });

    test('há exatamente 11 categorias, como no sistema antigo', () {
      expect(TransactionCategory.values, hasLength(11));
    });
  });

  group('copyWith', () {
    final original = Transaction(
      id: 't1',
      userId: 'u1',
      amount: 10,
      direction: TransactionDirection.saida,
      type: TransactionType.pix,
      date: DateTime(2026, 1, 1),
      category: TransactionCategory.lazer,
      description: 'Cinema',
      receiptUrl: 'https://exemplo/recibo.jpg',
    );

    test('sem argumentos, devolve uma cópia igual', () {
      final copia = original.copyWith();
      expect(copia.id, original.id);
      expect(copia.amount, original.amount);
      expect(copia.category, original.category);
      expect(copia.description, original.description);
      expect(copia.receiptUrl, original.receiptUrl);
    });

    test('troca só o campo informado', () {
      final copia = original.copyWith(amount: 99);
      expect(copia.amount, 99);
      expect(copia.description, 'Cinema', reason: 'o resto fica intacto');
    });

    test('passar null NÃO limpa campo opcional — é a limitação do copyWith', () {
      // Documentado de propósito: para remover o recibo, a tela constrói uma
      // Transaction nova em vez de chamar copyWith(receiptUrl: null).
      final copia = original.copyWith(receiptUrl: null);
      expect(copia.receiptUrl, original.receiptUrl);
    });
  });
}
