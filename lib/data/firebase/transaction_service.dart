import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TransactionService {
  // Pega a instância do Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Referência tipada da coleção, pra não repetir a string 'transactions'
  // em todo método (e o Dart já saber que o documento é um Map).
  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('transactions');

  // 1. Adicionar uma nova transação
  Future<void> addTransaction(Map<String, dynamic> transactionData) async {
    try {
      // Adiciona um novo "documento" dentro da "coleção" chamada 'transactions'
      await _collection.add(transactionData);
    } catch (e) {
      debugPrint("Erro ao adicionar transação: $e");
      // Repassa o erro pra tela conseguir avisar o usuário que não salvou.
      // Sem isso o formulário fecharia como se tivesse dado certo.
      rethrow;
    }
  }

  // 2. Ler as transações em TEMPO REAL (Stream)
  // Ao invés de Future (que busca uma vez só), usamos Stream.
  // Se mudar algo no banco, a tela atualiza na hora sem o usuário dar F5!
  Stream<QuerySnapshot> getUserTransactions(String userId) {
    return _collection
        .where(
          'userId',
          isEqualTo: userId,
        ) // Pega só as transações DESTE usuário
        .orderBy('date', descending: true) // Ordena da mais nova pra mais velha
        .snapshots();
  }

  // 3. Deletar transação
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _collection.doc(transactionId).delete();
    } catch (e) {
      debugPrint("Erro ao deletar: $e");
      rethrow;
    }
  }

  // 4. Buscar UMA transação pelo id
  // Usado pela tela de edição, que recebe só o id pela rota
  // (/transactions/:id/edit) e precisa preencher o formulário.
  // Retorna null quando o documento não existe (ex.: foi deletado enquanto
  // o usuário estava com o link aberto).
  Future<DocumentSnapshot<Map<String, dynamic>>?> getTransactionById(
    String transactionId,
  ) async {
    try {
      final doc = await _collection.doc(transactionId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      debugPrint("Erro ao buscar transação: $e");
      rethrow;
    }
  }

  // 5. Atualizar uma transação existente
  Future<void> updateTransaction(
    String transactionId,
    Map<String, dynamic> transactionData,
  ) async {
    try {
      await _collection.doc(transactionId).update(transactionData);
    } catch (e) {
      debugPrint("Erro ao atualizar transação: $e");
      rethrow;
    }
  }
}
