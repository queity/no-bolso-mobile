import 'package:firebase_auth/firebase_auth.dart';

/// Acesso direto ao Firebase Auth (antigo `AuthService`). Usado só pelo
/// `AuthRepositoryImpl`.
///
/// Lança [FirebaseAuthException] em caso de erro; a tradução para o erro de
/// domínio acontece no repositório.
class FirebaseAuthDatasource {
  FirebaseAuthDatasource({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;
  // `late` pra não tocar o Firebase ao montar telas em testes de widget.
  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;

  /// Usa `userChanges()` e não `authStateChanges()`: o segundo só avisa
  /// login e logout, e no cadastro o nome é salvo *depois* do login
  /// automático — o app ficava mostrando "Usuário" até reabrir.
  /// `userChanges()` também avisa atualizações de perfil (como o nome).
  Stream<User?> authStateChanges() => _auth.userChanges();

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<User?> signUp(String name, String email, String password) async {
    // 1. Cria a conta normalmente
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Atualiza o perfil do usuário recém-criado com o nome dele
    await result.user?.updateDisplayName(name);

    // 3. Recarrega os dados do usuário para garantir que o nome apareça na hora
    await result.user?.reload();

    return _auth.currentUser;
  }

  Future<void> signOut() => _auth.signOut();
}
