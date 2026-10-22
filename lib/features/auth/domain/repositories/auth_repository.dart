import '../entities/app_user.dart';

/// Contrato de autenticação. Implementado sobre o Firebase Auth em
/// `data/repositories/auth_repository_impl.dart`.
///
/// Todos os métodos lançam [AuthException] em caso de erro.
abstract interface class AuthRepository {
  /// Emite o usuário logado (ou `null`) sempre que a sessão mudar.
  Stream<AppUser?> authStateChanges();

  Future<AppUser?> signIn({required String email, required String password});

  Future<AppUser?> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signOut();
}
