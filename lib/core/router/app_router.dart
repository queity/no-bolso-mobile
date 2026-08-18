import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/transactions/form/transaction_form_screen.dart';
import '../../screens/transactions/list/transactions_list_screen.dart';
import 'main_shell.dart';

/// Nomes de rota centralizados para evitar strings soltas pelo app.
abstract class AppRoutes {
  static const splash = 'splash';
  static const login = 'login';
  static const register = 'register';
  static const dashboard = 'dashboard';
  static const transactions = 'transactions';
  static const newTransaction = 'new-transaction';
  static const editTransaction = 'edit-transaction';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Monta a configuração central de navegação do app (go_router).
///
/// Recebe o [authProvider] como parâmetro (em vez de usar um singleton
/// global) pra poder ser reconstruído com uma instância diferente nos
/// testes, sem depender do Firebase de verdade — quem chama (normalmente
/// `main.dart`) é responsável por criar e compartilhar a mesma instância
/// de [AuthProvider] usada no `MultiProvider`.
///
/// O Dashboard e a listagem de Transações vivem dentro de um
/// `StatefulShellRoute` com bottom navigation bar (ver `MainShell`) — o
/// Dashboard é a tela principal do app, conforme os requisitos do desafio.
/// As telas de Nova/Editar transação são empurradas por cima, fora da shell
/// (sem bottom nav), usando `parentNavigatorKey`.
GoRouter buildAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,

    // Sem isso, o redirect só é reavaliado quando alguém navega
    // explicitamente (context.go/push). Com isso, toda vez que o
    // AuthProvider chamar notifyListeners() (ex.: o Firebase resolveu a
    // sessão salva do usuário, ou um logout em outro dispositivo), o
    // GoRouter reavalia o redirect sozinho, sem precisar de navegação manual.
    refreshListenable: authProvider,

    redirect: (context, state) {
      final isAuth = authProvider.isAuth;

      // Verifica em qual tela o usuário está tentando entrar
      final isSplash = state.matchedLocation == '/';
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // REGRA 1: Se NÃO está logado e tenta ir para qualquer lugar (exceto splash e login/registro)
      if (!isAuth && !isSplash && !isAuthRoute) {
        return '/login'; // <-- Redireciona o usuário para o login!
      }

      // REGRA 2: Se ESTÁ logado, não faz sentido ele conseguir acessar a tela de Login ou Criar Conta
      if (isAuth && isAuthRoute) {
        return '/dashboard'; // <-- Redireciona o usuário direto para o app!
      }

      // REGRA 3: Se estiver tudo certo, permite a navegação normalmente
      return null;
    },

    routes: [
      GoRoute(
        path: '/',
        name: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                name: AppRoutes.transactions,
                builder: (context, state) => const TransactionsListScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/transactions/new',
        name: AppRoutes.newTransaction,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TransactionFormScreen(),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        name: AppRoutes.editTransaction,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            TransactionFormScreen(transactionId: state.pathParameters['id']),
      ),
    ],
  );
}
