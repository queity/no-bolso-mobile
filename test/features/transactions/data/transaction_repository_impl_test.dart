import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/transactions/data/datasources/transaction_firestore_datasource.dart';
import 'package:no_bolso_mobile/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';

/// Datasource falso: registra o que recebeu, sem tocar no Firestore.
///
/// Os métodos que devolvem tipos do Firestore (`watchByUser`, `getById`)
/// ficam de fora — exigiriam simular `QuerySnapshot`, e o que importa aqui
/// é provar que o repositório converte entidade → mapa antes de descer.
class _FakeDatasource implements TransactionFirestoreDatasource {
  final List<Map<String, dynamic>> added = [];
  final List<({String id, Map<String, dynamic> data})> updated = [];
  final List<String> deleted = [];

  @override
  Future<void> add(Map<String, dynamic> data) async => added.add(data);

  @override
  Future<void> update(String id, Map<String, dynamic> data) async =>
      updated.add((id: id, data: data));

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchByUser(String userId) =>
      throw UnimplementedError();

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>?> getById(String id) =>
      throw UnimplementedError();
}

void main() {
  late _FakeDatasource datasource;
  late TransactionRepositoryImpl repository;

  setUp(() {
    datasource = _FakeDatasource();
    repository = TransactionRepositoryImpl(datasource);
  });

  Transaction build({String? id}) {
    return Transaction(
      id: id,
      userId: 'u1',
      amount: 42.5,
      direction: TransactionDirection.saida,
      type: TransactionType.pix,
      date: DateTime(2026, 5, 20),
      category: TransactionCategory.alimentacao,
      description: 'Mercado',
    );
  }

  test('add converte a entidade em mapa do Firestore', () async {
    await repository.add(build());

    expect(datasource.added, hasLength(1));
    final map = datasource.added.single;
    expect(map['userId'], 'u1');
    expect(map['amount'], 42.5);
    expect(map['direction'], 'saida', reason: 'enum vira string legível');
    expect(map['type'], 'pix');
    expect(map['category'], 'alimentacao');
    expect(map['description'], 'Mercado');
    expect(map['receiptUrl'], isNull);
    expect(
      map['date'],
      isA<Timestamp>(),
      reason: 'DateTime do domínio vira Timestamp só na camada data',
    );
    expect((map['date'] as Timestamp).toDate(), DateTime(2026, 5, 20));
    expect(map.containsKey('id'), isFalse, reason: 'o id é do documento');
  });

  test('update manda o id separado do corpo', () async {
    await repository.update(build(id: 't1'));

    expect(datasource.updated, hasLength(1));
    expect(datasource.updated.single.id, 't1');
    expect(datasource.updated.single.data['amount'], 42.5);
  });

  test('update sem id falha antes de chegar no datasource', () async {
    expect(
      () => repository.update(build()),
      throwsA(isA<ArgumentError>()),
    );
    expect(datasource.updated, isEmpty);
  });

  test('delete repassa o id', () async {
    await repository.delete('t9');
    expect(datasource.deleted, ['t9']);
  });
}
