import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/auth/data/datasources/firebase_auth_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/transactions/data/datasources/receipt_storage_datasource.dart';
import '../../features/transactions/data/datasources/transaction_firestore_datasource.dart';
import '../../features/transactions/data/repositories/receipt_repository_impl.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/receipt_repository.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/domain/usecases/save_transaction.dart';
import '../../features/transactions/presentation/providers/transaction_list_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';

/// Composição das dependências do app (o único lugar que conhece as
/// implementações concretas com Firebase).
///
/// As telas só enxergam os providers de estado ([AuthProvider],
/// [TransactionsProvider], [TransactionListProvider]); repositórios e casos
/// de uso ficam aqui dentro. Para testar, basta montar um [AppDependencies]
/// com repositórios fake.
class AppDependencies {
  AppDependencies({
    required this.authRepository,
    required this.transactionRepository,
    required this.receiptRepository,
  }) : authProvider = AuthProvider(authRepository),
       saveTransaction = SaveTransaction(
         transactionRepository,
         receiptRepository,
       );

  /// Implementações reais, sobre o Firebase.
  factory AppDependencies.firebase() {
    return AppDependencies(
      authRepository: AuthRepositoryImpl(FirebaseAuthDatasource()),
      transactionRepository: TransactionRepositoryImpl(
        TransactionFirestoreDatasource(),
      ),
      receiptRepository: ReceiptRepositoryImpl(ReceiptStorageDatasource()),
    );
  }

  final AuthRepository authRepository;
  final TransactionRepository transactionRepository;
  final ReceiptRepository receiptRepository;
  final SaveTransaction saveTransaction;

  /// Instância única, compartilhada entre o `MultiProvider` (telas) e o
  /// GoRouter (`refreshListenable` dispara o redirect quando a sessão muda).
  final AuthProvider authProvider;

  List<SingleChildWidget> get providers => [
    ChangeNotifierProvider<AuthProvider>.value(value: authProvider),

    // Segue o usuário logado: troca de stream no login e limpa tudo no
    // logout, sem nenhuma tela precisar pedir.
    ChangeNotifierProxyProvider<AuthProvider, TransactionsProvider>(
      create: (_) =>
          TransactionsProvider(transactionRepository, saveTransaction),
      update: (_, auth, transactions) =>
          transactions!..bindUser(auth.user?.id),
    ),

    // Recarrega a listagem paginada quando as transações mudam.
    ChangeNotifierProxyProvider2<
      AuthProvider,
      TransactionsProvider,
      TransactionListProvider
    >(
      create: (_) => TransactionListProvider(transactionRepository),
      update: (_, auth, transactions, list) =>
          list!..sync(userId: auth.user?.id, revision: transactions.revision),
    ),
  ];
}
