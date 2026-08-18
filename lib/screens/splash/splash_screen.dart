import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Tela inicial exibida enquanto verificamos o estado de autenticação.
///
/// Espera o [AuthProvider] terminar de checar a sessão salva do usuário
/// (`isInitializing == false`) antes de navegar, em vez de um tempo fixo —
/// senão um usuário já logado poderia ser mandado pro login por engano só
/// porque o Firebase ainda não tinha respondido. Um atraso mínimo garante
/// que a marca apareça mesmo quando o Firebase responde na hora.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 600);

  bool _minimumDelayElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minimumSplashDuration, () {
      if (!mounted) return;
      setState(() => _minimumDelayElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // context.watch reconstrói esta tela sempre que o AuthProvider mudar
    // (ex.: o Firebase termina de resolver a sessão salva).
    final isInitializing = context.watch<AuthProvider>().isInitializing;

    if (_minimumDelayElapsed && !isInitializing) {
      // Sempre tenta ir pro dashboard: se o usuário não estiver autenticado,
      // o `redirect` do GoRouter (em app_router.dart) intercepta e manda
      // pro /login sozinho. Isso evita duplicar a checagem de isAuth aqui.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard');
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 44,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Bolso',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
