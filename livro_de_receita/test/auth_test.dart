import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_de_receita/data/auth_service.dart';
import 'package:livro_de_receita/pages/login_page.dart';
import 'package:livro_de_receita/widgets/auth_gate.dart';

import 'fakes.dart';

Future<void> _abrirLogin(WidgetTester tester, FakeAuthService auth) async {
  await tester.pumpWidget(MaterialApp(home: LoginPage(auth: auth)));
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  final alvo = find.text(texto);
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pump();
}

void main() {
  group('mensagemErroAuth', () {
    test('não revela se o e-mail existe e explica a falta de internet', () {
      expect(mensagemErroAuth('user-not-found'), 'E-mail ou senha incorretos.');
      expect(mensagemErroAuth('wrong-password'), 'E-mail ou senha incorretos.');
      expect(mensagemErroAuth('invalid-credential'), 'E-mail ou senha incorretos.');
      expect(mensagemErroAuth('network-request-failed'), contains('internet'));
      expect(mensagemErroAuth('codigo-desconhecido'), 'Não foi possível concluir. Tente de novo.');
    });
  });

  group('LoginPage', () {
    testWidgets('valida e-mail e senha antes de chamar o Firebase', (tester) async {
      final auth = FakeAuthService();
      await _abrirLogin(tester, auth);

      await _tocar(tester, 'Entrar');

      expect(find.text('Informe o e-mail'), findsOneWidget);
      expect(find.text('Informe a senha'), findsOneWidget);
      expect(auth.chamadas, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(0), 'sem-arroba');
      await _tocar(tester, 'Entrar');
      expect(find.text('E-mail inválido'), findsOneWidget);
    });

    testWidgets('entra com e-mail e senha e mostra o erro do login', (tester) async {
      final auth = FakeAuthService()..falha = const AuthFailure('E-mail ou senha incorretos.');
      await _abrirLogin(tester, auth);

      await tester.enterText(find.byType(TextFormField).at(0), ' ana@exemplo.com ');
      await tester.enterText(find.byType(TextFormField).at(1), 'segredo1');
      await _tocar(tester, 'Entrar');
      await tester.pump();

      expect(auth.chamadas, ['signIn: ana@exemplo.com :segredo1']);
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    });

    testWidgets('criar conta pede confirmação e senha de 6 caracteres', (tester) async {
      final auth = FakeAuthService();
      await _abrirLogin(tester, auth);

      await _tocar(tester, 'Não tem conta? Criar conta');
      expect(find.byType(TextFormField), findsNWidgets(3));

      await tester.enterText(find.byType(TextFormField).at(0), 'ana@exemplo.com');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.enterText(find.byType(TextFormField).at(2), '12399');
      await _tocar(tester, 'Criar conta');
      expect(find.text('Use pelo menos 6 caracteres'), findsOneWidget);
      expect(find.text('As senhas não são iguais'), findsOneWidget);
      expect(auth.chamadas, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await _tocar(tester, 'Criar conta');
      await tester.pump();
      expect(auth.chamadas, ['register:ana@exemplo.com:123456']);
    });

    testWidgets('esqueci a senha pede o e-mail e envia o link', (tester) async {
      final auth = FakeAuthService();
      await _abrirLogin(tester, auth);

      await _tocar(tester, 'Esqueci minha senha');
      expect(find.textContaining('Digite seu e-mail'), findsOneWidget);
      expect(auth.chamadas, isEmpty);

      await tester.enterText(find.byType(TextFormField).at(0), 'ana@exemplo.com');
      await _tocar(tester, 'Esqueci minha senha');
      await tester.pump();
      expect(auth.chamadas, ['reset:ana@exemplo.com']);
      expect(find.textContaining('enviamos um link'), findsOneWidget);
    });
  });

  group('AuthGate', () {
    Widget gate(FakeAuthService auth, List<String> eventos) => MaterialApp(
      home: AuthGate(
        auth: auth,
        onSignedIn: (uid) async => eventos.add('entrou:$uid'),
        onSignedOut: () => eventos.add('saiu'),
        home: const Text('Tela inicial'),
      ),
    );

    testWidgets('sem usuário mostra o login', (tester) async {
      final eventos = <String>[];
      await tester.pumpWidget(gate(FakeAuthService(), eventos));
      await tester.pump();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(eventos, ['saiu']);
    });

    testWidgets('com usuário prepara os dados e mostra a tela inicial; sair volta ao login', (
      tester,
    ) async {
      final eventos = <String>[];
      final auth = FakeAuthService(uidInicial: 'u1');
      await tester.pumpWidget(gate(auth, eventos));
      await tester.pump();
      await tester.pump();

      expect(find.text('Tela inicial'), findsOneWidget);
      expect(eventos, ['entrou:u1']);

      await auth.signOut();
      await tester.pump();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(eventos, ['entrou:u1', 'saiu']);
    });
  });
}
