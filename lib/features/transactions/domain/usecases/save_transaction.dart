import '../entities/transaction.dart';
import '../repositories/receipt_repository.dart';
import '../repositories/transaction_repository.dart';

/// Caso de uso: salvar (criar ou editar) uma transação com recibo.
///
/// Essa orquestração antes vivia dentro da tela do formulário. A ordem dos
/// passos é regra de negócio, não de UI:
///
/// 1. Se há recibo novo, ele sobe primeiro — se o upload falhar, a transação
///    não é salva pela metade.
/// 2. Grava a transação (cria quando não tem id, atualiza quando tem).
/// 3. Só depois de gravar é seguro apagar o recibo antigo, se ele foi
///    trocado ou removido — evita arquivo órfão no Storage.
class SaveTransaction {
  const SaveTransaction(this._transactions, this._receipts);

  final TransactionRepository _transactions;
  final ReceiptRepository _receipts;

  Future<void> call(
    Transaction transaction, {
    String? newReceiptPath,
    String? previousReceiptUrl,
  }) async {
    var toSave = transaction;

    if (newReceiptPath != null) {
      final url = await _receipts.upload(
        filePath: newReceiptPath,
        userId: transaction.userId,
      );
      toSave = transaction.copyWith(receiptUrl: url);
    }

    if (toSave.id == null) {
      await _transactions.add(toSave);
    } else {
      await _transactions.update(toSave);
    }

    if (previousReceiptUrl != null && previousReceiptUrl != toSave.receiptUrl) {
      await _receipts.delete(previousReceiptUrl);
    }
  }
}
