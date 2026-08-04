import 'package:flutter/material.dart';

/// Placeholder da tela de login/autenticação.
/// TODO: implementar fluxo de autenticação com Firebase Auth.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(
        child: Text('Tela de Login (placeholder)'),
      ),
    );
  }
}
