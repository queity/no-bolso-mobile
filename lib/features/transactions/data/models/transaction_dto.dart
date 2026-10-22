// `hide Transaction`: o cloud_firestore exporta uma classe `Transaction` (a
// de `runTransaction`) que colidiria com a nossa entidade de domínio.
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../domain/entities/transaction.dart';

/// Tradução entre a entidade [Transaction] e o documento do Firestore.
///
/// Tudo que é detalhe de persistência mora aqui: `Timestamp`, nomes dos
/// campos e a compatibilidade com os códigos numéricos do sistema antigo.
abstract final class TransactionDto {
  static Transaction fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  static Transaction fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['date'];

    return Transaction(
      id: id,
      userId: map['userId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      direction: _enumFromValue(
        TransactionDirection.values,
        map['direction'],
        (e) => e.codigo,
      ) ??
          TransactionDirection.saida,
      type: _enumFromValue(TransactionType.values, map['type'], (e) => e.codigo) ??
          TransactionType.pix,
      // Documentos podem ter vindo sem data ou com string — por isso não
      // assumimos Timestamp cegamente.
      date: rawDate is Timestamp
          ? rawDate.toDate()
          : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now(),
      category: _enumFromValue(
        TransactionCategory.values,
        map['category'],
        (e) => e.codigo,
      ),
      description: map['description'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
    );
  }

  /// Formato gravado no Firestore. O `id` fica de fora de propósito — ele é o
  /// id do documento, não um campo dentro dele. Gravamos o `name` dos enums
  /// (`entrada`, `pix`...), que é legível direto no console.
  static Map<String, dynamic> toMap(Transaction t) {
    return {
      'userId': t.userId,
      'amount': t.amount,
      'direction': t.direction.name,
      'type': t.type.name,
      'date': Timestamp.fromDate(t.date),
      'category': t.category?.name,
      'description': t.description,
      'receiptUrl': t.receiptUrl,
    };
  }

  /// Resolve um enum a partir do que veio do Firestore.
  ///
  /// Aceita tanto o `name` (o formato que gravamos) quanto o `codigo`
  /// numérico do sistema antigo — se um dia alguém importar os dados de lá,
  /// nada quebra.
  static T? _enumFromValue<T extends Enum>(
    List<T> values,
    Object? value,
    int Function(T) codigoOf,
  ) {
    if (value is String) {
      for (final item in values) {
        if (item.name == value) return item;
      }
    }
    if (value is num) {
      for (final item in values) {
        if (codigoOf(item) == value.toInt()) return item;
      }
    }
    return null;
  }
}
