import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:no_bolso_mobile/core/router/app_router.dart';
import 'package:no_bolso_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:no_bolso_mobile/main.dart';

import 'fakes/fake_auth_repository.dart';

void main() {
  testWidgets('App inicializa e mostra a splash screen', (
    WidgetTester tester,
  ) async {
    // Stream vazio: nunca emite um usuário, então o AuthProvider fica
    // "deslogado" sem precisar inicializar o Firebase de verdade no teste.
    final authProvider = AuthProvider(FakeAuthRepository());
    addTearDown(authProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authProvider,
        child: MyApp(router: buildAppRouter(authProvider)),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A Splash agenda um Timer pro atraso mínimo antes de tentar navegar.
    // Como o stream de auth do teste nunca emite, `isInitializing` nunca
    // vira `false` e a navegação nunca acontece de fato — mas avançamos o
    // relógio do teste mesmo assim pra esse timer disparar e não sobrar
    // pendente quando a árvore de widgets for descartada no fim do teste
    // (o flutter_test falha o teste se isso acontecer).
    await tester.pump(const Duration(milliseconds: 600));
  });
}
