// Camada de DOMÍNIO: Dart puro. Nada de Flutter, Firebase ou qualquer outro
// pacote de infraestrutura aqui — é isso que permite testar as regras do app
// sem banco e trocar a fonte de dados sem mexer nas telas.
//
// A conversão de/para o Firestore (Timestamp, nomes de campo, códigos
// numéricos legados) fica em `data/models/transaction_dto.dart`.

/// Direção da transação: se o dinheiro entra ou sai.
///
/// Equivale ao `DirecaoTransacao` do No Bolso web — o `codigo` é o mesmo de lá
/// para facilitar qualquer integração futura.
enum TransactionDirection {
  entrada(1, 'Entrada'),
  saida(2, 'Saída');

  const TransactionDirection(this.codigo, this.label);

  final int codigo;
  final String label;

  bool get isIncome => this == TransactionDirection.entrada;
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
}

/// Uma transação financeira do usuário (entidade de domínio).
///
/// Antes se chamava `TransactionModel` porque o `cloud_firestore` também
/// exporta uma classe `Transaction`. Como o domínio não importa mais o
/// Firestore, o nome natural voltou a ser possível; só a camada `data`
/// precisa de `hide Transaction` no import do `cloud_firestore`.
class Transaction {
  const Transaction({
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

  /// Id da transação na fonte de dados. Nulo enquanto não foi salva.
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

  /// URL do recibo anexado. Nulo quando não há anexo.
  final String? receiptUrl;

  bool get isIncome => direction.isIncome;

  /// Valor com sinal, pronto pra somatórios de saldo.
  double get signedAmount => isIncome ? amount : -amount;

  Transaction copyWith({
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
    return Transaction(
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
