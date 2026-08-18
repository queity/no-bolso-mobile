import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionService {
  // `late` pra não tocar o Firebase na hora de criar o TransactionService
  // (ex.: em testes de widget que só montam a tela) — só acessa de verdade
  // quando um dos métodos abaixo é chamado.
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Adicionar uma nova transação
  Future<void> addTransaction(Map<String, dynamic> transactionData) async {
    try {
      // Adiciona um novo "documento" dentro da "coleção" chamada 'transactions'
      await _db.collection('transactions').add(transactionData);
    } catch (e) {
      print("Erro ao adicionar transação: $e");
    }
  }

  // 2. Ler as transações em TEMPO REAL (Stream)
  // Ao invés de Future (que busca uma vez só), usamos Stream.
  // Se mudar algo no banco, a tela atualiza na hora sem o usuário dar F5!
  Stream<QuerySnapshot> getUserTransactions(String userId) {
    return _db
        .collection('transactions')
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
      await _db.collection('transactions').doc(transactionId).delete();
    } catch (e) {
      print("Erro ao deletar: $e");
    }
  }
}
