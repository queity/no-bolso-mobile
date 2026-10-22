import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:no_bolso_mobile/features/transactions/domain/usecases/save_transaction.dart';

import '../../../fakes/fake_transaction_repositories.dart';

void main() {
  late FakeTransactionRepository transactions;
  late FakeReceiptRepository receipts;
  late SaveTransaction saveTransaction;

  Transaction buildTransaction({String? id, String? receiptUrl}) => Transaction(
    id: id,
    userId: 'u1',
    amount: 50,
    direction: TransactionDirection.saida,
    type: TransactionType.pix,
    date: DateTime(2026, 10, 1),
    receiptUrl: receiptUrl,
  );

  setUp(() {
    transactions = FakeTransactionRepository();
    receipts = FakeReceiptRepository();
    saveTransaction = SaveTransaction(transactions, receipts);
  });

  test('sem id, cria a transação', () async {
    await saveTransaction(buildTransaction());

    expect(transactions.added, hasLength(1));
    expect(transactions.updated, isEmpty);
  });

  test('com id, atualiza a transação', () async {
    await saveTransaction(buildTransaction(id: 't1'));

    expect(transactions.updated.single.id, 't1');
    expect(transactions.added, isEmpty);
  });

  test('com recibo novo, sobe o arquivo e salva com a URL do upload', () async {
    await saveTransaction(buildTransaction(), newReceiptPath: '/tmp/r.jpg');

    expect(receipts.uploaded, ['/tmp/r.jpg']);
    expect(transactions.added.single.receiptUrl, 'https://fake/u1/1.jpg');
  });

  test('trocar o recibo apaga o antigo', () async {
    await saveTransaction(
      buildTransaction(id: 't1', receiptUrl: 'https://old.jpg'),
      newReceiptPath: '/tmp/novo.jpg',
      previousReceiptUrl: 'https://old.jpg',
    );

    expect(receipts.deleted, ['https://old.jpg']);
  });

  test('remover o recibo apaga o antigo', () async {
    await saveTransaction(
      buildTransaction(id: 't1'),
      previousReceiptUrl: 'https://old.jpg',
    );

    expect(transactions.updated.single.receiptUrl, isNull);
    expect(receipts.deleted, ['https://old.jpg']);
  });

  test('manter o mesmo recibo não apaga nada', () async {
    await saveTransaction(
      buildTransaction(id: 't1', receiptUrl: 'https://old.jpg'),
      previousReceiptUrl: 'https://old.jpg',
    );

    expect(receipts.deleted, isEmpty);
  });

  test('se o upload falhar, a transação não é salva', () async {
    saveTransaction = SaveTransaction(
      transactions,
      FakeReceiptRepository(failUpload: true),
    );

    await expectLater(
      saveTransaction(buildTransaction(), newReceiptPath: '/tmp/r.jpg'),
      throwsException,
    );
    expect(transactions.added, isEmpty);
  });
}
