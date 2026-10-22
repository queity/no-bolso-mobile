import 'package:no_bolso_mobile/features/auth/domain/entities/app_user.dart';
import 'package:no_bolso_mobile/features/auth/domain/repositories/auth_repository.dart';

/// [AuthRepository] em memória para testes — não toca o Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Stream<AppUser?>? authStateChanges})
    : _authStateChanges = authStateChanges ?? const Stream<AppUser?>.empty();

  final Stream<AppUser?> _authStateChanges;

  @override
  Stream<AppUser?> authStateChanges() => _authStateChanges;

  @override
  Future<AppUser?> signIn({required String email, required String password}) async =>
      AppUser(id: 'fake-uid', email: email);

  @override
  Future<AppUser?> signUp({
    required String name,
    required String email,
    required String password,
  }) async => AppUser(id: 'fake-uid', name: name, email: email);

  @override
  Future<void> signOut() async {}
}
