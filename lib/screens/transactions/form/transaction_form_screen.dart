import 'package:flutter/material.dart';

/// Placeholder da tela de Adicionar/Editar Transação.
/// TODO: validação avançada de campos e upload de recibos para o Firebase Storage.
class TransactionFormScreen extends StatelessWidget {
  const TransactionFormScreen({super.key, this.transactionId});

  /// Quando nulo, a tela está em modo de criação. Caso contrário, edição.
  final String? transactionId;

  @override
  Widget build(BuildContext context) {
    final isEditing = transactionId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Transação' : 'Nova Transação'),
      ),
      body: Center(
        child: Text(
          isEditing
              ? 'Editar transação $transactionId (placeholder)'
              : 'Nova transação (placeholder)',
        ),
      ),
    );
  }
}
