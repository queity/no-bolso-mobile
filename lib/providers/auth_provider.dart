import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// O ChangeNotifier avisa quem estiver "ouvindo" quando algo mudar
class AuthProvider extends ChangeNotifier {
  User? _user; // Variável que guarda o usuário logado

  User? get user => _user; // Forma segura de ler o usuário
  bool get isAuth => _user != null; // Retorna true se estiver logado

  // O construtor que fica escutando o Firebase
  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? newUser) {
      _user = newUser;
      notifyListeners(); // <--- O GRANDE SEGREDO!
      // Esse notifyListeners() grita para o app: "TELA, SE ATUALIZE! O USUÁRIO LOGOU!"
    });
  }
}
