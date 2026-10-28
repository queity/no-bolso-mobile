import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Estado global de autenticação.
///
/// O ChangeNotifier avisa quem estiver "ouvindo" (telas, GoRouter e o
/// `TransactionsProvider`) quando o usuário loga ou desloga. As telas também
/// fazem login, cadastro e logout por aqui, sem conhecer o repositório.
///
/// Depende só do [AuthRepository] — nos testes, basta um repositório fake.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository) {
    _subscription = _repository.authStateChanges().listen((AppUser? newUser) {
      _user = newUser;
      _isInitializing = false;
      notifyListeners(); // "TELA, SE ATUALIZE! O USUÁRIO MUDOU!"
    });
  }

  final AuthRepository _repository;
  AppUser? _user;
  late final StreamSubscription<AppUser?> _subscription;

  // Fica `true` até o primeiro evento do authStateChanges chegar. Antes
  // disso, `isAuth == false` não quer dizer "deslogado" — pode ser que o
  // Firebase ainda esteja checando a sessão salva do usuário. A Splash usa
  // isso pra não mandar um usuário já logado pro login por engano.
  bool _isInitializing = true;

  AppUser? get user => _user;
  bool get isAuth => _user != null;
  bool get isInitializing => _isInitializing;

  /// Lança `AuthException` em caso de erro. O estado ([user]) é atualizado
  /// pelo stream de sessão, não pelo retorno.
  Future<void> signIn({required String email, required String password}) {
    return _repository.signIn(email: email, password: password);
  }

  /// Lança `AuthException` em caso de erro.
  ///
  /// O stream de sessão emite o usuário assim que a conta é criada, ainda
  /// sem o nome. Por isso, ao terminar, já atualiza com o usuário completo
  /// devolvido pelo cadastro, sem depender do próximo evento do stream.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final created = await _repository.signUp(
      name: name,
      email: email,
      password: password,
    );
    if (created != null && created.id == _user?.id) {
      _user = created;
      notifyListeners();
    }
  }

  /// Ao sair, o stream de sessão emite `null`, o GoRouter manda pro login e
  /// o `TransactionsProvider` descarta os dados do usuário.
  Future<void> signOut() => _repository.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
