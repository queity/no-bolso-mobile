import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/dashboard/domain/entities/dashboard_period.dart';
import 'package:no_bolso_mobile/features/transactions/domain/usecases/save_transaction.dart';
import 'package:no_bolso_mobile/features/transactions/presentation/providers/transactions_provider.dart';

import '../../../fakes/fake_transaction_repositories.dart';
import '../../../helpers/transaction_builders.dart';

/// Deixa rodar os microtasks/eventos de stream pendentes.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeTransactionRepository repository;
  late TransactionsProvider provider;
  late int notifications;

  setUp(() {
    repository = FakeTransactionRepository();
    provider = TransactionsProvider(
      repository,
      SaveTransaction(repository, FakeReceiptRepository()),
      clock: () => DateTime(2026, 10, 26),
    );
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  tearDown(() => provider.dispose());

  test('ao logar, carrega as transações do stream', () async {
    provider.bindUser('u1');
    expect(provider.isLoading, isTrue);

    repository.emit([buildTx(id: 'a'), buildTx(id: 'b')]);
    await flush();

    expect(repository.watchedUserIds, ['u1']);
    expect(provider.isLoading, isFalse);
    expect(provider.transactions.map((t) => t.id), ['a', 'b']);
  });

  test('o mesmo usuário não cria uma segunda assinatura', () async {
    provider.bindUser('u1');
    provider.bindUser('u1');
    provider.bindUser('u1');

    expect(repository.watchedUserIds, ['u1']);
  });

  test('bindUser não notifica de forma síncrona (é chamado durante o build)', () async {
    provider.bindUser('u1');
    expect(notifications, 0);

    await flush();
    expect(notifications, 1);
  });

  test('ao sair, descarta os dados do usuário anterior', () async {
    provider.bindUser('u1');
    repository.emit([buildTx(id: 'a')]);
    await flush();

    provider.bindUser(null);

    expect(provider.transactions, isEmpty);
    expect(provider.isLoading, isFalse);
  });

  test('erro no stream vira estado de erro, e retry assina de novo', () async {
    provider.bindUser('u1');
    repository.emitError(Exception('offline'));
    await flush();

    expect(provider.hasError, isTrue);

    provider.retry();
    expect(provider.hasError, isFalse);
    expect(provider.isLoading, isTrue);
    expect(repository.watchedUserIds, ['u1', 'u1']);
  });

  test('revision muda a cada atualização dos dados', () async {
    provider.bindUser('u1');
    final afterBind = provider.revision;

    repository.emit([buildTx(id: 'a')]);
    await flush();

    expect(provider.revision, greaterThan(afterBind));
  });

  test('summaryFor reaproveita o cálculo até os dados mudarem', () async {
    provider.bindUser('u1');
    repository.emit([buildTx(amount: 10)]);
    await flush();

    final first = provider.summaryFor(DashboardPeriod.month);
    expect(identical(first, provider.summaryFor(DashboardPeriod.month)), isTrue);
    expect(first.expenses, 10);

    repository.emit([buildTx(amount: 10), buildTx(amount: 5)]);
    await flush();

    final second = provider.summaryFor(DashboardPeriod.month);
    expect(identical(first, second), isFalse);
    expect(second.expenses, 15);
  });

  test('getById usa a cópia em memória antes de ir ao repositório', () async {
    provider.bindUser('u1');
    repository.emit([buildTx(id: 'a')]);
    await flush();

    expect((await provider.getById('a'))?.id, 'a');
    expect(repository.getByIdCalls, 0);

    repository.byId['z'] = buildTx(id: 'z');
    expect((await provider.getById('z'))?.id, 'z');
    expect(repository.getByIdCalls, 1);
  });

  test('save cria pelo caso de uso; delete repassa ao repositório', () async {
    await provider.save(buildTx());
    await provider.delete('x');

    expect(repository.added, hasLength(1));
    expect(repository.deleted, ['x']);
  });
}
