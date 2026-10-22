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

/// Composição das dependências do app (o único lugar que conhece as
/// implementações concretas com Firebase).
///
/// As telas pedem as *interfaces* via `context.read<TransactionRepository>()`
/// etc. Para testar, basta montar um [AppDependencies] com fakes.
class AppDependencies {
  AppDependencies({
    required this.authRepository,
    required this.transactionRepository,
    required this.receiptRepository,
  }) : authProvider = AuthProvider(authRepository);

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

  /// Instância única, compartilhada entre o `MultiProvider` (telas) e o
  /// GoRouter (`refreshListenable` dispara o redirect quando a sessão muda).
  final AuthProvider authProvider;

  List<SingleChildWidget> get providers => [
    Provider<AuthRepository>.value(value: authRepository),
    Provider<TransactionRepository>.value(value: transactionRepository),
    Provider<ReceiptRepository>.value(value: receiptRepository),
    Provider<SaveTransaction>.value(
      value: SaveTransaction(transactionRepository, receiptRepository),
    ),
    ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
  ];
}
