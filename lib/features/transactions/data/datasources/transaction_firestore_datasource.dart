import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Acesso direto à coleção `transactions` do Firestore (antigo
/// `TransactionService`).
///
/// Fala só a "língua" do Firestore (`Map`, `QuerySnapshot`,
/// `DocumentSnapshot`). Quem traduz isso para entidades de domínio é o
/// `TransactionRepositoryImpl` — as telas nunca usam esta classe direto.
class TransactionFirestoreDatasource {
  /// Aceita uma instância customizada (ex.: `FakeFirebaseFirestore` em
  /// testes). Sem nada, usa a real — mas só quando um método é chamado
  /// (`late`), pra não tocar o Firebase ao montar telas em testes de widget.
  TransactionFirestoreDatasource({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  late final FirebaseFirestore _db =
      _firestoreOverride ?? FirebaseFirestore.instance;

  // Referência tipada da coleção, pra não repetir a string 'transactions'
  // em todo método (e o Dart já saber que o documento é um Map).
  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('transactions');

  Future<void> add(Map<String, dynamic> data) async {
    try {
      await _collection.add(data);
    } catch (e) {
      debugPrint("Erro ao adicionar transação: $e");
      // Repassa o erro pra tela conseguir avisar o usuário que não salvou.
      rethrow;
    }
  }

  // Tempo real: se mudar algo no banco, quem escuta recebe a lista nova.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> delete(String id) async {
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      debugPrint("Erro ao deletar: $e");
      rethrow;
    }
  }

  /// Retorna null quando o documento não existe (ex.: foi deletado enquanto
  /// o usuário estava com o link de edição aberto).
  Future<DocumentSnapshot<Map<String, dynamic>>?> getById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      return doc.exists ? doc : null;
    } catch (e) {
      debugPrint("Erro ao buscar transação: $e");
      rethrow;
    }
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    try {
      await _collection.doc(id).update(data);
    } catch (e) {
      debugPrint("Erro ao atualizar transação: $e");
      rethrow;
    }
  }

  /// Busca uma PÁGINA de transações, com filtros (usado pela listagem).
  ///
  /// Busca única (`.get()`, não `.snapshots()`) — é o que permite paginar por
  /// cursor (`startAfterDocument`). A página já carregada não se atualiza
  /// sozinha se o dado mudar no servidor.
  ///
  /// Com `category` e período juntos, o Firestore exige um índice composto
  /// (userId + category + date) — ver `firestore.indexes.json`.
  Future<QuerySnapshot<Map<String, dynamic>>> getPage({
    required String userId,
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection.where(
        'userId',
        isEqualTo: userId,
      );

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      if (startDate != null && endDate != null) {
        // `endDate` vem só com a data (00:00) — inclui o dia inteiro, senão
        // transações do próprio dia final ficariam de fora.
        final inclusiveEnd = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        );
        query = query
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(inclusiveEnd));
      }

      query = query.orderBy('date', descending: true).limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      return await query.get();
    } catch (e) {
      debugPrint("Erro ao buscar página de transações: $e");
      rethrow;
    }
  }
}
