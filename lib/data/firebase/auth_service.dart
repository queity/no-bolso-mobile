import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // `late` pra não tocar o Firebase na hora de criar o AuthService (ex.: em
  // testes de widget que só montam a tela, sem realmente logar) — só acessa
  // de verdade quando um dos métodos abaixo é chamado.
  late final FirebaseAuth _auth = FirebaseAuth.instance;

  // Função de Login.
  //
  // Lança [FirebaseAuthException] em caso de erro (senha errada, usuário
  // não existe, sem internet etc.) — quem chamar decide como mostrar isso
  // pro usuário, em vez do erro real ser descartado aqui.
  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  // Função de Cadastro (SignUp).
  //
  // Lança [FirebaseAuthException] em caso de erro (e-mail já em uso, senha
  // fraca etc.).
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

    // Retorna o usuário atualizado
    return _auth.currentUser;
  }

  // Função de Sair (SignOut)
  Future<void> signOut() => _auth.signOut();
}
