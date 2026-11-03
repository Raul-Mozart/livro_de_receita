// T-163: o campo Categoria passou de `value` para `initialValue` + `key: ValueKey(_categoriaId)`.
// Risco: categoria carregada por código (edição, rascunho) não aparecer selecionada.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_de_receita/data/receita_repository.dart';
import 'package:livro_de_receita/models/receita.dart';
import 'package:livro_de_receita/pages/cadastro_page.dart';

import 'fakes.dart';

class _RepoComReceita extends RepositorioDeTeste {
  _RepoComReceita(this.receita);
  final Receita? receita;

  @override
  Future<Receita?> getById(String id) async => receita;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const imagePicker = MethodChannel('plugins.flutter.io/image_picker');
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(imagePicker, (call) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(imagePicker, null);
    messenger.setMockMethodCallHandler(pathProvider, null);
    ReceitaRepository.desconectar();
  });

  int? valorDoCampo(WidgetTester tester) =>
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value;

  // Abre a tela deixando o I/O real (path_provider, arquivos) completar
  Future<void> abrir(
    WidgetTester tester,
    Widget tela, {
    Directory? docs,
  }) async {
    final dir = docs ?? Directory.systemTemp.createTempSync('t163_');
    if (docs == null) addTearDown(() => dir.deleteSync(recursive: true));
    messenger.setMockMethodCallHandler(pathProvider, (call) async => dir.path);
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: tela));
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'T-163 receita nova: primeira categoria do catálogo já vem selecionada',
    (tester) async {
      await abrir(tester, const Cadastro());
      expect(valorDoCampo(tester), 3);
      expect(find.text('Bebidas'), findsOneWidget);
    },
  );

  testWidgets(
    'T-163 edição: categoria da receita (Salgados) aparece selecionada',
    (tester) async {
      ReceitaRepository.conectar(
        _RepoComReceita(receitaExemplo(id: 'r1', categoriaId: 1)),
      );
      await abrir(tester, const Cadastro(recipeId: 'r1'));

      expect(valorDoCampo(tester), 1);
      expect(find.text('Salgados'), findsOneWidget);
      expect(find.text('Bebidas'), findsNothing);
    },
  );

  testWidgets(
    'T-163 edição: usuário troca a categoria depois de carregada e o form valida',
    (tester) async {
      ReceitaRepository.conectar(
        _RepoComReceita(receitaExemplo(id: 'r1', categoriaId: 1)),
      );
      await abrir(tester, const Cadastro(recipeId: 'r1'));

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doces').last);
      await tester.pumpAndSettle();

      expect(valorDoCampo(tester), 2);
      expect(find.text('Doces'), findsOneWidget);
      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isTrue);
      await tester.pump();
      expect(find.text('Selecione uma categoria'), findsNothing);
    },
  );

  testWidgets('T-163 rascunho: categoria salva (Doces) aparece selecionada', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('t163_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/rascunho_receita.json').writeAsStringSync(
      jsonEncode({
        'nome': 'Brigadeiro',
        'categoriaId': 2,
        'ingredientes': [],
        'passos': [],
      }),
    );
    await abrir(tester, const Cadastro(), docs: dir);

    expect(find.text('Brigadeiro'), findsOneWidget);
    expect(valorDoCampo(tester), 2);
    expect(find.text('Doces'), findsOneWidget);
    expect(find.text('Bebidas'), findsNothing);
  });

  // BUG-L03 (anterior ao T-163): o DropdownButton exige exatamente um item com o valor; id fora do catálogo
  // dispara assert em debug. A tela ignora o id desconhecido e fica com a categoria atual.
  testWidgets(
    'T-163 limite: receita com categoria fora do catálogo não quebra a tela',
    (tester) async {
      ReceitaRepository.conectar(
        _RepoComReceita(receitaExemplo(id: 'r9', categoriaId: 99)),
      );
      await abrir(tester, const Cadastro(recipeId: 'r9'));
      expect(tester.takeException(), isNull);
      expect(find.text('Editar Receita'), findsOneWidget);
    },
  );
}
