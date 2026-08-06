import 'package:flutter/material.dart';

/// Placeholder da tela de Adicionar/Editar Transação.
/// TODO: validação avançada de campos e upload de recibos para o Firebase Storage.
class TransactionFormScreen extends StatelessWidget {
  const TransactionFormScreen({super.key, this.transactionId});

  /// Quando nulo, a tela está em modo de criação. Caso contrário, edição.
  final String? transactionId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isEditing = transactionId != null;

    return Scaffold(
      // Sem título no AppBar: fica só o botão de voltar (a tela é aberta
      // por cima da bottom nav). O título fica estilizado no corpo, igual
      // à listagem de transações.
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Editar Transação' : 'Nova Transação',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    isEditing
                        ? 'Editar transação $transactionId (placeholder)'
                        : 'Nova transação (placeholder)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
