import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// O ChangeNotifier avisa quem estiver "ouvindo" quando algo mudar
class AuthProvider extends ChangeNotifier {
  /// Por padrão escuta o Firebase Auth de verdade. Aceita um
  /// [authStateChanges] customizado pra permitir testar sem precisar
  /// inicializar o Firebase (ex.: `Stream<User?>.empty()` nos testes).
  AuthProvider({Stream<User?>? authStateChanges}) {
    _subscription =
        (authStateChanges ?? FirebaseAuth.instance.authStateChanges()).listen(
          (User? newUser) {
            _user = newUser;
            _isInitializing = false;
            notifyListeners(); // <--- O GRANDE SEGREDO!
            // Esse notifyListeners() grita para o app: "TELA, SE ATUALIZE! O USUÁRIO LOGOU!"
          },
        );
  }

  User? _user; // Variável que guarda o usuário logado
  late final StreamSubscription<User?> _subscription;

  // Fica `true` até o primeiro evento do authStateChanges chegar. Antes
  // disso, `isAuth == false` não quer dizer "deslogado" — pode ser que o
  // Firebase ainda esteja checando a sessão salva do usuário. A Splash usa
  // isso pra não mandar um usuário já logado pro login por engano.
  bool _isInitializing = true;

  User? get user => _user; // Forma segura de ler o usuário
  bool get isAuth => _user != null; // Retorna true se estiver logado
  bool get isInitializing => _isInitializing;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
