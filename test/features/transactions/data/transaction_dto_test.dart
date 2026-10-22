import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/transactions/data/models/transaction_dto.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';

void main() {
  test('ida e volta: toMap -> fromMap preserva os dados', () {
    final original = Transaction(
      userId: 'u1',
      amount: 12.5,
      direction: TransactionDirection.entrada,
      type: TransactionType.transferencia,
      date: DateTime(2026, 10, 1, 12),
      category: TransactionCategory.receitasFixas,
      description: 'Salário',
    );

    final map = TransactionDto.toMap(original);
    final restored = TransactionDto.fromMap('doc1', map);

    expect(map['direction'], 'entrada');
    expect(map['date'], isA<Timestamp>());
    expect(restored.id, 'doc1');
    expect(restored.amount, 12.5);
    expect(restored.direction, TransactionDirection.entrada);
    expect(restored.type, TransactionType.transferencia);
    expect(restored.category, TransactionCategory.receitasFixas);
    expect(restored.date, original.date);
  });

  test('aceita os códigos numéricos do sistema antigo', () {
    final t = TransactionDto.fromMap('doc1', {
      'userId': 'u1',
      'amount': 10,
      'direction': 1,
      'type': 4,
      'category': 9,
      'date': '2026-01-15',
    });

    expect(t.direction, TransactionDirection.entrada);
    expect(t.type, TransactionType.saque);
    expect(t.category, TransactionCategory.transporte);
    expect(t.date, DateTime(2026, 1, 15));
  });

  test('valores ausentes ou inválidos usam os padrões', () {
    final t = TransactionDto.fromMap('doc1', {'direction': 'xpto'});

    expect(t.direction, TransactionDirection.saida);
    expect(t.type, TransactionType.pix);
    expect(t.category, isNull);
    expect(t.amount, 0);
  });
}
