import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:no_bolso_mobile/features/transactions/presentation/providers/transaction_list_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../../helpers/transaction_builders.dart';

// `testWidgets` em vez de `test`: ele roda num relógio falso, controlado por
// `tester.pump(duração)`. Assim dá pra testar o debounce de 300ms com
// precisão, sem esperar tempo de verdade.

const debounce = Duration(milliseconds: 300);

final almoco = buildTx(
  id: 'almoco',
  description: 'Almoço no restaurante',
  category: TransactionCategory.alimentacao,
  date: DateTime(2026, 10, 10),
);
final uber = buildTx(
  id: 'uber',
  description: 'Uber para o trabalho',
  category: TransactionCategory.transporte,
  date: DateTime(2026, 9, 5),
);
final cinema = buildTx(
  id: 'cinema',
  description: 'Cinema',
  category: TransactionCategory.lazer,
  date: DateTime(2026, 10, 20),
);

List<String?> ids(List<Transaction> list) => [for (final t in list) t.id];

void main() {
  late BehaviorSubject<List<Transaction>> source;
  late TransactionListProvider list;
  late int notifications;

  /// Monta o provider sobre um stream controlado pelo teste (no app, é o
  /// `transactionsStream` do `TransactionsProvider`) e entrega a primeira
  /// lista.
  Future<void> start(WidgetTester tester, List<Transaction> initial) async {
    source = BehaviorSubject<List<Transaction>>.seeded(initial);
    list = TransactionListProvider(source.stream, pageSize: 2);
    list.bindUser('u1');
    addTearDown(() {
      list.dispose();
      source.close();
    });
    await tester.pump();
    notifications = 0;
    list.addListener(() => notifications++);
  }

  testWidgets('sem filtro, mostra as transações na ordem do stream', (
    tester,
  ) async {
    await start(tester, [almoco, uber]);

    expect(ids(list.items), ['almoco', 'uber']);
    expect(list.hasActiveFilters, isFalse);
  });

  group('busca com debounce', () {
    testWidgets('só aplica depois de 300ms sem digitar', (tester) async {
      await start(tester, [almoco, uber, cinema]);

      list.setQuery('almo');
      await tester.pump(const Duration(milliseconds: 299));
      expect(ids(list.items), ['almoco', 'uber'], reason: 'ainda esperando');

      await tester.pump(const Duration(milliseconds: 1));
      expect(ids(list.items), ['almoco']);
      expect(list.appliedQuery, 'almo');
    });

    testWidgets('digitação rápida filtra uma vez só, com o último texto', (
      tester,
    ) async {
      await start(tester, [almoco, uber, cinema]);

      for (final text in ['u', 'ub', 'ube', 'uber']) {
        list.setQuery(text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(notifications, 0);

      await tester.pump(debounce);
      expect(notifications, 1);
      expect(ids(list.items), ['uber']);
    });

    testWidgets('apagar a busca volta a lista na hora', (tester) async {
      await start(tester, [almoco, uber, cinema]);
      list.setQuery('cinema');
      await tester.pump(debounce);
      expect(ids(list.items), ['cinema']);

      list.setQuery('');
      await tester.pump();

      expect(list.hasQuery, isFalse);
      expect(ids(list.items), ['almoco', 'uber']);
      expect(list.resultCount, 3);
    });

    testWidgets('mesma busca com acento, maiúscula ou espaço não refaz o '
        'filtro', (tester) async {
      await start(tester, [almoco, uber]);
      list.setQuery('almoco');
      await tester.pump(debounce);
      final depoisDaPrimeira = notifications;

      list.setQuery('  ALMOÇO ');
      await tester.pump(debounce);

      expect(notifications, depoisDaPrimeira);
    });
  });

  group('categoria e período', () {
    testWidgets('aplicam na hora, sem esperar o debounce', (tester) async {
      await start(tester, [almoco, uber, cinema]);

      list.setCategory(TransactionCategory.lazer);
      await tester.pump();
      expect(ids(list.items), ['cinema']);

      list.setCategory(null);
      list.setDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      await tester.pump();
      expect(ids(list.items), ['almoco', 'cinema']);
      expect(list.hasDateRange, isTrue);
    });

    testWidgets('combinam com a busca', (tester) async {
      await start(tester, [almoco, uber, cinema]);

      list.setDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      list.setQuery('restaurante');
      await tester.pump(debounce);

      expect(ids(list.items), ['almoco']);
    });

    testWidgets('clearFilters limpa categoria, período e busca', (
      tester,
    ) async {
      await start(tester, [almoco, uber, cinema]);
      list.setCategory(TransactionCategory.lazer);
      list.setDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      list.setQuery('cinema');
      await tester.pump(debounce);

      list.clearFilters();
      await tester.pump();

      expect(list.hasActiveFilters, isFalse);
      expect(list.resultCount, 3);
    });
  });

  testWidgets('transação nova no stream já chega filtrada', (tester) async {
    await start(tester, [almoco, uber]);
    list.setQuery('restaurante');
    await tester.pump(debounce);

    final jantar = buildTx(id: 'jantar', description: 'Jantar no restaurante');
    source.add([jantar, almoco, uber]);
    await tester.pump();

    expect(ids(list.items), ['jantar', 'almoco']);
  });

  group('rolagem (pageSize = 2)', () {
    final muitas = [
      for (var i = 0; i < 5; i++) buildTx(id: '$i', description: 'item $i'),
    ];

    testWidgets('mostra de 2 em 2 com loadMore', (tester) async {
      await start(tester, muitas);
      expect(ids(list.items), ['0', '1']);
      expect(list.hasMore, isTrue);

      list.loadMore();
      list.loadMore();
      expect(ids(list.items), ['0', '1', '2', '3', '4']);
      expect(list.hasMore, isFalse);

      list.loadMore(); // sem mais nada: não faz nada
      expect(list.items, hasLength(5));
    });

    testWidgets('trocar filtro ou busca volta para o começo', (tester) async {
      await start(tester, muitas);
      list.loadMore();
      expect(list.items, hasLength(4));

      list.setQuery('item');
      await tester.pump(debounce);
      expect(list.items, hasLength(2));
    });

    testWidgets('dados novos não encolhem o que já estava visível', (
      tester,
    ) async {
      await start(tester, muitas);
      list.loadMore();

      source.add([buildTx(id: 'novo'), ...muitas]);
      await tester.pump();

      expect(ids(list.items), ['novo', '0', '1', '2']);
    });
  });

  testWidgets('trocar de usuário zera busca e filtros', (tester) async {
    await start(tester, [almoco, uber, cinema]);
    list.setCategory(TransactionCategory.lazer);
    list.setQuery('cinema');
    await tester.pump(debounce);

    list.bindUser('u2');
    await tester.pump();

    expect(list.category, isNull);
    expect(list.hasQuery, isFalse);
    expect(list.hasActiveFilters, isFalse);
  });
}
