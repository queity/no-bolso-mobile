import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction_filter.dart';

import '../../../helpers/transaction_builders.dart';

void main() {
  group('normalize', () {
    test('tira acentos, passa para minúsculas e junta espaços', () {
      expect(TransactionFilter.normalize('  Almoço  NO Café '), 'almoco no cafe');
      expect(TransactionFilter.normalize('Ônibus à noite, pão e maçã'),
          'onibus a noite, pao e maca');
    });

    test('texto só com espaços vira vazio', () {
      expect(TransactionFilter.normalize('   '), '');
    });
  });

  group('busca por descrição', () {
    final almoco = buildTx(id: 'a', description: 'Almoço no restaurante');
    final uber = buildTx(id: 'b', description: 'Uber para o trabalho');
    final semDescricao = buildTx(id: 'c');
    final todas = [almoco, uber, semDescricao];

    List<String?> ids(List<Transaction> list) => [for (final t in list) t.id];

    test('ignora maiúsculas e acentos', () {
      expect(ids(const TransactionFilter(query: 'ALMOCO').apply(todas)), ['a']);
      expect(ids(const TransactionFilter(query: 'almoço').apply(todas)), ['a']);
    });

    test('encontra trecho no meio da descrição', () {
      expect(ids(const TransactionFilter(query: 'staura').apply(todas)), ['a']);
    });

    test('todas as palavras precisam aparecer, em qualquer ordem', () {
      expect(
        ids(const TransactionFilter(query: 'restaurante almoço').apply(todas)),
        ['a'],
      );
      expect(
        ids(const TransactionFilter(query: 'almoço trabalho').apply(todas)),
        isEmpty,
      );
    });

    test('transação sem descrição não aparece numa busca', () {
      expect(ids(const TransactionFilter(query: 'a').apply(todas)),
          isNot(contains('c')));
    });

    test('busca vazia ou só com espaços não filtra nada', () {
      expect(const TransactionFilter(query: '   ').apply(todas), same(todas));
      expect(const TransactionFilter(query: '   ').isEmpty, isTrue);
    });
  });

  group('categoria e período', () {
    test('filtra pela categoria', () {
      final saude = buildTx(id: 's', category: TransactionCategory.saude);
      final lazer = buildTx(id: 'l', category: TransactionCategory.lazer);
      final semCategoria = buildTx(id: 'n');

      final result = const TransactionFilter(
        category: TransactionCategory.saude,
      ).apply([saude, lazer, semCategoria]);

      expect(result, [saude]);
    });

    test('o período inclui o primeiro e o último dia inteiros', () {
      final antes = buildTx(id: '1', date: DateTime(2026, 9, 30, 23, 59));
      final inicio = buildTx(id: '2', date: DateTime(2026, 10, 1));
      final fimDoUltimoDia = buildTx(id: '3', date: DateTime(2026, 10, 31, 23, 30));
      final depois = buildTx(id: '4', date: DateTime(2026, 11, 1));

      final result = TransactionFilter(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      ).apply([antes, inicio, fimDoUltimoDia, depois]);

      expect(result, [inicio, fimDoUltimoDia]);
    });

    test('só a data inicial, sem a final, não filtra por período', () {
      final filter = TransactionFilter(startDate: DateTime(2026, 10, 1));
      expect(filter.hasDateRange, isFalse);
      expect(filter.matches(buildTx(date: DateTime(2020))), isTrue);
    });
  });

  test('critérios combinados: precisa passar em todos', () {
    final certa = buildTx(
      id: 'ok',
      category: TransactionCategory.alimentacao,
      date: DateTime(2026, 10, 10),
      description: 'Feira do mês',
    );
    final outraCategoria = buildTx(
      category: TransactionCategory.lazer,
      date: DateTime(2026, 10, 10),
      description: 'Feira do mês',
    );
    final foraDoPeriodo = buildTx(
      category: TransactionCategory.alimentacao,
      date: DateTime(2026, 8, 10),
      description: 'Feira do mês',
    );
    final outraDescricao = buildTx(
      category: TransactionCategory.alimentacao,
      date: DateTime(2026, 10, 10),
      description: 'Padaria',
    );

    final result = TransactionFilter(
      category: TransactionCategory.alimentacao,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
      query: 'feira',
    ).apply([certa, outraCategoria, foraDoPeriodo, outraDescricao]);

    expect(result, [certa]);
  });

  test('a ordem original da lista é mantida', () {
    final a = buildTx(id: 'a', description: 'café');
    final b = buildTx(id: 'b', description: 'Café da manhã');
    final c = buildTx(id: 'c', description: 'cafe');

    expect(const TransactionFilter(query: 'cafe').apply([c, a, b]), [c, a, b]);
  });
}
