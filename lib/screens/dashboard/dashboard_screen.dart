import 'package:flutter/material.dart';

/// Placeholder do Dashboard.
/// TODO: exibir gráficos e análises financeiras das transações do usuário.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(
        child: Text('Dashboard (placeholder)'),
      ),
    );
  }
}
