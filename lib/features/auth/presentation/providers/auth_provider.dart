import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Estado global de autenticação.
///
/// O ChangeNotifier avisa quem estiver "ouvindo" (telas e o GoRouter) quando
/// o usuário loga ou desloga. Depende só do [AuthRepository] — nos testes,
/// basta passar um repositório fake, sem inicializar o Firebase.
class AuthProvider extends ChangeNotifier {
  AuthProvider(AuthRepository repository) {
    _subscription = repository.authStateChanges().listen((AppUser? newUser) {
      _user = newUser;
      _isInitializing = false;
      notifyListeners(); // "TELA, SE ATUALIZE! O USUÁRIO MUDOU!"
    });
  }

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

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
