import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/errors/auth_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_datasource.dart';

/// Implementação de [AuthRepository] sobre o Firebase Auth.
///
/// Converte `User` → [AppUser] e `FirebaseAuthException` → [AuthException],
/// pra nenhuma tela precisar importar o firebase_auth.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource);

  final FirebaseAuthDatasource _datasource;

  @override
  Stream<AppUser?> authStateChanges() {
    return _datasource.authStateChanges().map(_toAppUser);
  }

  @override
  Future<AppUser?> signIn({required String email, required String password}) {
    return _guard(() async => _toAppUser(await _datasource.signIn(email, password)));
  }

  @override
  Future<AppUser?> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard(
      () async => _toAppUser(await _datasource.signUp(name, email, password)),
    );
  }

  @override
  Future<void> signOut() => _guard(_datasource.signOut);

  static AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(id: user.uid, name: user.displayName, email: user.email);
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }
}
