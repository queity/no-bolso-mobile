import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/transactions/form/transaction_form_screen.dart';
import '../../screens/transactions/list/transactions_list_screen.dart';
import 'main_shell.dart';

/// Nomes de rota centralizados para evitar strings soltas pelo app.
abstract class AppRoutes {
  static const splash = 'splash';
  static const login = 'login';
  static const dashboard = 'dashboard';
  static const transactions = 'transactions';
  static const newTransaction = 'new-transaction';
  static const editTransaction = 'edit-transaction';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Configuração central de navegação do app (go_router).
///
/// O Dashboard e a listagem de Transações vivem dentro de um
/// `StatefulShellRoute` com bottom navigation bar (ver `MainShell`) — o
/// Dashboard é a tela principal do app, conforme os requisitos do desafio.
/// As telas de Nova/Editar transação são empurradas por cima, fora da shell
/// (sem bottom nav), usando `parentNavigatorKey`.
///
/// TODO: adicionar redirect com base no estado de autenticação
/// (Firebase Auth) quando o fluxo de login estiver implementado.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
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
      builder: (context, state) => TransactionFormScreen(
        transactionId: state.pathParameters['id'],
      ),
    ),
  ],
);
