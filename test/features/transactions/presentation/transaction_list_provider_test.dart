import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction_page.dart';
import 'package:no_bolso_mobile/features/transactions/presentation/providers/transaction_list_provider.dart';

import '../../../fakes/fake_transaction_repositories.dart';
import '../../../helpers/transaction_builders.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

TransactionPage page(List<String> ids, {bool hasMore = false, Object? cursor}) {
  return TransactionPage(
    items: [for (final id in ids) buildTx(id: id)],
    hasMore: hasMore,
    cursor: cursor ?? (ids.isEmpty ? null : ids.last),
  );
}

void main() {
  late FakeTransactionRepository repository;
  late TransactionListProvider list;

  setUp(() {
    repository = FakeTransactionRepository();
    list = TransactionListProvider(repository, pageSize: 2);
  });

  tearDown(() => list.dispose());

  test('ao logar, já começa carregando e busca a primeira página', () async {
    repository.pages.add(page(['a', 'b'], hasMore: true));

    list.sync(userId: 'u1', revision: 0);
    expect(list.isLoadingFirstPage, isTrue);
    await flush();

    expect(list.isLoadingFirstPage, isFalse);
    expect(list.items.map((t) => t.id), ['a', 'b']);
    expect(list.hasMore, isTrue);
  });

  test('loadNextPage continua do cursor da página anterior', () async {
    repository.pages
      ..add(page(['a', 'b'], hasMore: true))
      ..add(page(['c']));
    list.sync(userId: 'u1', revision: 0);
    await flush();

    await list.loadNextPage();

    expect(repository.pageCalls.last.after, 'b');
    expect(list.items.map((t) => t.id), ['a', 'b', 'c']);
    expect(list.hasMore, isFalse);
  });

  test('quando as transações mudam (revision), recarrega sozinha', () async {
    repository.pages
      ..add(page(['a']))
      ..add(page(['novo', 'a']));
    list.sync(userId: 'u1', revision: 0);
    await flush();

    list.sync(userId: 'u1', revision: 1);
    await flush();

    expect(repository.pageCalls, hasLength(2));
    expect(list.items.map((t) => t.id), ['novo', 'a']);
  });

  test('a mesma revision não dispara outra busca', () async {
    list.sync(userId: 'u1', revision: 3);
    await flush();
    list.sync(userId: 'u1', revision: 3);
    await flush();

    expect(repository.pageCalls, hasLength(1));
  });

  test('filtros vão para a busca e recomeçam da primeira página', () async {
    list.sync(userId: 'u1', revision: 0);
    await flush();

    await list.setCategory(TransactionCategory.lazer);
    expect(repository.pageCalls.last.filter.category, TransactionCategory.lazer);
    expect(repository.pageCalls.last.after, isNull);
    expect(list.hasActiveFilters, isTrue);

    await list.clearFilters();
    expect(repository.pageCalls.last.filter.category, isNull);
    expect(list.hasActiveFilters, isFalse);
  });

  test('ao sair, limpa a lista e os filtros', () async {
    repository.pages.add(page(['a']));
    list.sync(userId: 'u1', revision: 0);
    await flush();
    await list.setCategory(TransactionCategory.casa);

    list.sync(userId: null, revision: 1);

    expect(list.items, isEmpty);
    expect(list.category, isNull);
    expect(list.isLoadingFirstPage, isFalse);
  });
}
