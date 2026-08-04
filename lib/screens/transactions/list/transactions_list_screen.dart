import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder da listagem de transações.
/// TODO: filtros avançados, paginação/scroll infinito e busca via Cloud Firestore.
class TransactionsListScreen extends StatelessWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transações')),
      body: const Center(
        child: Text('Lista de Transações (placeholder)'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
