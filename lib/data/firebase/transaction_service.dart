import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../models/transaction.dart';

class TransactionService {
  // `late` pra não tocar o Firebase na hora de criar o TransactionService
  // (ex.: em testes de widget que só montam a tela) — só acessa de verdade
  // quando um dos métodos abaixo é chamado.
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // 6. Buscar uma PÁGINA de transações, com filtros (usado pela listagem).
  //
  // Diferente de `getUserTransactions`, aqui é uma busca única (`.get()`,
  // não `.snapshots()`) — é o que permite paginar por cursor
  // (`startAfterDocument`). Isso tem um custo: a página já carregada não se
  // atualiza sozinha se o dado mudar no servidor; quem chama deve dar um
  // "puxar para atualizar" ou recarregar a primeira página quando precisar
  // de dados frescos.
  //
  // `dateRange` e `category` são opcionais — quando nenhum dos dois é
  // informado, a query é equivalente à de `getUserTransactions` (só que
  // paginada). Quando os dois são informados juntos, o Firestore exige um
  // índice composto (userId + category + date) — ver `firestore.indexes.json`.
  Future<QuerySnapshot<Map<String, dynamic>>> getTransactionsPage({
    required String userId,
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    DateTimeRange? dateRange,
    TransactionCategory? category,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection.where(
        'userId',
        isEqualTo: userId,
      );

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      if (dateRange != null) {
        // `end` vem só com a data (00:00) — inclui o dia inteiro somando
        // quase 24h, senão transações do próprio dia final ficariam de fora.
        final inclusiveEnd = DateTime(
          dateRange.end.year,
          dateRange.end.month,
          dateRange.end.day,
          23,
          59,
          59,
          999,
        );
        query = query
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start),
            )
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
