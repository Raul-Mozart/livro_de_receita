import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_de_receita/pages/cadastro_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A tela pergunta ao image_picker se há foto perdida (app fechado pela câmera); no teste não há
  const imagePicker = MethodChannel('plugins.flutter.io/image_picker');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imagePicker, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imagePicker, null);
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Cadastro()));
    await tester.pumpAndSettle();
  }

  FocusNode focoDoNome(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Digite o nome da receita'),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode;

  Future<void> tocar(WidgetTester tester, Finder alvo) async {
    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
    await tester.tap(alvo);
    await tester.pumpAndSettle();
  }

  // B-001: ao fechar o diálogo, o foco voltava ao nome, o teclado abria e a tela rolava ao topo
  testWidgets('adicionar ingrediente não devolve o foco ao nome da receita', (tester) async {
    await abrir(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Digite o nome da receita'), 'Suco');
    expect(focoDoNome(tester).hasFocus, isTrue);

    await tocar(tester, find.text('Adicionar Ingrediente'));
    await tester.enterText(find.widgetWithText(TextField, 'Nome do ingrediente'), 'Laranja');
    await tocar(tester, find.widgetWithText(TextButton, 'Adicionar'));

    expect(find.textContaining('Laranja'), findsOneWidget);
    expect(focoDoNome(tester).hasFocus, isFalse);
  });

  testWidgets('adicionar passo não devolve o foco ao nome da receita', (tester) async {
    await abrir(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Digite o nome da receita'), 'Suco');

    await tocar(tester, find.text('Adicionar Passo'));
    await tester.enterText(find.widgetWithText(TextField, 'Descrição do passo'), 'Espremer');
    await tocar(tester, find.widgetWithText(TextButton, 'Adicionar'));

    expect(find.text('1. Espremer'), findsOneWidget);
    expect(focoDoNome(tester).hasFocus, isFalse);
  });
}
