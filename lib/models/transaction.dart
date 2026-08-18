import 'package:cloud_firestore/cloud_firestore.dart';

/// Direção da transação: se o dinheiro entra ou sai.
///
/// Equivale ao `DirecaoTransacao` do No Bolso web — o `codigo` é o mesmo de lá
/// para facilitar qualquer integração futura, mas no Firestore gravamos o
/// `name` (`entrada` / `saida`), que é legível direto no console.
enum TransactionDirection {
  entrada(1, 'Entrada'),
  saida(2, 'Saída');

  const TransactionDirection(this.codigo, this.label);

  final int codigo;
  final String label;

  bool get isIncome => this == TransactionDirection.entrada;

  static TransactionDirection fromValue(Object? value) {
    // O fallback não é nulo, então o resultado também não é.
    return _enumFromValue(
      TransactionDirection.values,
      value,
      TransactionDirection.saida,
    )!;
  }
}

/// Meio pelo qual a transação aconteceu. Espelha o `TipoTransacao` do No Bolso
/// web, onde o campo é obrigatório e o padrão é Pix.
enum TransactionType {
  pix(1, 'Pix'),
  deposito(2, 'Depósito'),
  transferencia(3, 'Transferência'),
  saque(4, 'Saque'),
  outros(5, 'Outros');

  const TransactionType(this.codigo, this.label);

  final int codigo;
  final String label;

  static TransactionType fromValue(Object? value) {
    return _enumFromValue(TransactionType.values, value, TransactionType.pix)!;
  }
}

/// Categorias da transação — os mesmos 11 valores do `CategoriaTransacao` do
/// No Bolso web, para o app mobile não inventar uma taxonomia paralela.
///
/// Assim como no sistema antigo, a categoria é opcional.
enum TransactionCategory {
  alimentacao(1, 'Alimentação'),
  lazer(2, 'Lazer'),
  assinatura(3, 'Assinatura'),
  casa(4, 'Casa'),
  educacao(5, 'Educação'),
  receitasFixas(6, 'Receitas Fixas'),
  outros(7, 'Outros'),
  saude(8, 'Saúde'),
  transporte(9, 'Transporte'),
  receitasVariaveis(10, 'Receitas Variáveis'),
  viagem(11, 'Viagem');

  const TransactionCategory(this.codigo, this.label);

  final int codigo;
  final String label;

  /// Direção que combina com a categoria, como no `direction-suggestion` do
  /// web: receitas entram, o resto sai. `outros` fica sem palpite porque é
  /// ambíguo de propósito.
  TransactionDirection? get suggestedDirection {
    switch (this) {
      case TransactionCategory.receitasFixas:
      case TransactionCategory.receitasVariaveis:
        return TransactionDirection.entrada;
      case TransactionCategory.outros:
        return null;
      default:
        return TransactionDirection.saida;
    }
  }

  static TransactionCategory? fromValue(Object? value) {
    if (value == null) return null;
    return _enumFromValue<TransactionCategory>(
      TransactionCategory.values,
      value,
      null,
    );
  }
}

/// Resolve um enum a partir do que veio do Firestore.
///
/// Aceita tanto o `name` (o formato que gravamos) quanto o `codigo` numérico
/// do sistema antigo — se um dia alguém importar os dados de lá, nada quebra.
T? _enumFromValue<T extends Enum>(
  List<T> values,
  Object? value,
  T? fallback,
) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) return item;
    }
  }
  if (value is num) {
    for (final item in values) {
      if ((item as dynamic).codigo == value.toInt()) return item;
    }
  }
  return fallback;
}

/// Uma transação financeira do usuário.
///
/// O nome é `TransactionModel` e não `Transaction` de propósito: o
/// `cloud_firestore` já exporta uma classe chamada `Transaction` (a de
/// `runTransaction`), e os dois nomes colidiriam em qualquer arquivo que
/// importasse os dois pacotes.
class TransactionModel {
  const TransactionModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.direction,
    required this.type,
    required this.date,
    this.category,
    this.description,
    this.receiptUrl,
  });

  /// Id do documento no Firestore. Nulo enquanto a transação não foi salva.
  final String? id;
  final String userId;

  /// Valor sempre positivo — quem diz se soma ou subtrai é a [direction].
  final double amount;
  final TransactionDirection direction;
  final TransactionType type;
  final DateTime date;

  /// Opcional, como no No Bolso web ("Sem categoria").
  final TransactionCategory? category;

  /// Texto livre e opcional, no máximo 255 caracteres.
  final String? description;

  /// URL pública do recibo no Firebase Storage. Nulo quando não há anexo.
  final String? receiptUrl;

  bool get isIncome => direction.isIncome;

  /// Valor com sinal, pronto pra somatórios de saldo.
  double get signedAmount => isIncome ? amount : -amount;

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['date'];

    return TransactionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      direction: TransactionDirection.fromValue(map['direction']),
      type: TransactionType.fromValue(map['type']),
      // Documentos podem ter vindo sem data ou com string — por isso não
      // assumimos Timestamp cegamente.
      date: rawDate is Timestamp
          ? rawDate.toDate()
          : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now(),
      category: TransactionCategory.fromValue(map['category']),
      description: map['description'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
    );
  }

  /// Constrói a partir de um documento do Firestore.
  factory TransactionModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TransactionModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  /// Formato gravado no Firestore. O `id` fica de fora de propósito — ele é o
  /// id do documento, não um campo dentro dele.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'direction': direction.name,
      'type': type.name,
      'date': Timestamp.fromDate(date),
      'category': category?.name,
      'description': description,
      'receiptUrl': receiptUrl,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionDirection? direction,
    TransactionType? type,
    DateTime? date,
    TransactionCategory? category,
    String? description,
    String? receiptUrl,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}
