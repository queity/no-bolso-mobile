import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_bolso_mobile/features/auth/domain/entities/app_user.dart';
import 'package:no_bolso_mobile/features/auth/presentation/providers/auth_provider.dart';

import '../../../fakes/fake_auth_repository.dart';

void main() {
  test('após o cadastro, o usuário já aparece com o nome', () async {
    final session = StreamController<AppUser?>();
    final provider = AuthProvider(
      FakeAuthRepository(authStateChanges: session.stream),
    );
    addTearDown(() {
      provider.dispose();
      session.close();
    });

    // Como no Firebase: o login automático do cadastro chega antes do nome
    // ser salvo.
    session.add(const AppUser(id: 'fake-uid', email: 'maria@teste.com'));
    await Future<void>.delayed(Duration.zero);
    expect(provider.user?.firstName, isNull);

    await provider.signUp(
      name: 'Maria Silva',
      email: 'maria@teste.com',
      password: '123456',
    );

    expect(provider.user?.firstName, 'Maria');
  });
}
