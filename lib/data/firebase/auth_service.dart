import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Função de Login
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Erro no login: ${e.toString()}");
      return null;
    }
  }

  // Função de Cadastro (SignUp)
  Future<User?> signUp(String name, String email, String password) async {
    try {
      // 1. Cria a conta normalmente
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Atualiza o perfil do usuário recém-criado com o nome dele
      await result.user?.updateDisplayName(name);

      // 3. Recarrega os dados do usuário para garantir que o nome apareça na hora
      await result.user?.reload();

      // Retorna o usuário atualizado
      return _auth.currentUser;
    } catch (e) {
      print("Erro no cadastro: ${e.toString()}");
      return null;
    }
  }

  // Função de Sair (SignOut)
  Future<void> signOut() async {
    try {
      // Desloga o usuário do aplicativo
      await _auth.signOut();
    } catch (e) {
      print("Erro ao sair: ${e.toString()}");
    }
  }
}
