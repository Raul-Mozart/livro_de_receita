import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_de_receita/widgets/recipe_image_widget.dart';

/// D-009 (testador, 2026-11-01): sem `repararFotosDoAppAntigo`, receita que ainda aponta para a foto do app anterior
/// (pasta privada de com.example.lista_de_compras, ilegível por este app) precisa cair no ícone, sem quebrar a tela.
void main() {
  testWidgets('foto do app anterior inexistente mostra o ícone de reserva', (tester) async {
    const caminhoAntigo = '/data/user/0/com.example.lista_de_compras/app_flutter/foto_123.jpg';
    expect(File(caminhoAntigo).existsSync(), isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecipeImageWidget(imagePath: caminhoAntigo, width: 200, height: 150)),
      ),
    );
    // A leitura do arquivo é E/S real: dá tempo fora do relógio falso.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
  });

  testWidgets('sem caminho (nulo ou vazio) mostra o ícone de reserva', (tester) async {
    for (final caminho in [null, '']) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: RecipeImageWidget(imagePath: caminho))));
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    }
  });
}
