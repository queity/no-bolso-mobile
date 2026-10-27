import 'package:no_bolso_mobile/features/transactions/domain/entities/transaction.dart';

/// Cria uma transação de teste com só o que importa em cada caso.
Transaction buildTx({
  String? id,
  String userId = 'u1',
  double amount = 10,
  bool income = false,
  DateTime? date,
  TransactionCategory? category,
}) {
  return Transaction(
    id: id,
    userId: userId,
    amount: amount,
    direction: income ? TransactionDirection.entrada : TransactionDirection.saida,
    type: TransactionType.pix,
    date: date ?? DateTime(2026, 10, 15),
    category: category,
  );
}
