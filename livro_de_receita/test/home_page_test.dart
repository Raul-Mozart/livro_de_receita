import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_de_receita/data/receita_repository.dart';
import 'package:livro_de_receita/main.dart';

import 'fakes.dart';

void main() {
  late RepositorioDeTeste repo;

  setUp(() {
    repo = RepositorioDeTeste();
    ReceitaRepository.conectar(repo);
  });

  tearDown(ReceitaRepository.desconectar);

  Future<void> abrir(WidgetTester tester, FakeAuthService auth) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: LivroDeReceitas(auth: auth)));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra as receitas do usuário em cada categoria', (tester) async {
    repo.save(receitaExemplo(titulo: 'Coxinha', categoriaId: 1, imagem: 'assets/images/salgadinho.png'));
    repo.save(receitaExemplo(titulo: 'Bolo de cenoura', categoriaId: 2));

    await abrir(tester, FakeAuthService(uidInicial: 'u1', email: 'ana@exemplo.com'));

    expect(find.text('Coxinha'), findsOneWidget);
    expect(find.text('Bolo de cenoura'), findsOneWidget);
    // Bebidas ficou vazia
    expect(find.text('Nenhuma receita cadastrada'), findsOneWidget);
  });

  testWidgets('menu da conta mostra o e-mail e sai da conta', (tester) async {
    final auth = FakeAuthService(uidInicial: 'u1', email: 'ana@exemplo.com');
    await abrir(tester, auth);

    await tester.tap(find.byTooltip('Conta'));
    await tester.pumpAndSettle();
    expect(find.text('ana@exemplo.com'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(auth.chamadas, ['signOut']);
  });
}
