import 'package:go_router/go_router.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/transactions/form/transaction_form_screen.dart';
import '../../screens/transactions/list/transactions_list_screen.dart';

/// Nomes de rota centralizados para evitar strings soltas pelo app.
abstract class AppRoutes {
  static const splash = 'splash';
  static const login = 'login';
  static const dashboard = 'dashboard';
  static const transactions = 'transactions';
  static const newTransaction = 'new-transaction';
  static const editTransaction = 'edit-transaction';
}

/// Configuração central de navegação do app (go_router).
///
/// TODO: adicionar redirect com base no estado de autenticação
/// (Firebase Auth) quando o fluxo de login estiver implementado.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
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
      path: '/dashboard',
      name: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/transactions',
      name: AppRoutes.transactions,
      builder: (context, state) => const TransactionsListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          name: AppRoutes.newTransaction,
          builder: (context, state) => const TransactionFormScreen(),
        ),
        GoRoute(
          path: ':id/edit',
          name: AppRoutes.editTransaction,
          builder: (context, state) => TransactionFormScreen(
            transactionId: state.pathParameters['id'],
          ),
        ),
      ],
    ),
  ],
);
