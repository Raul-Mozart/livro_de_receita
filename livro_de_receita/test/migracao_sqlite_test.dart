import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_de_receita/data/migracao_sqlite.dart';
import 'package:livro_de_receita/data/receita_repository.dart';

// Linhas como o sqflite devolvia nas tabelas antigas (receita, ingrediente, passo_preparo)
final _receitas = <Map<String, Object?>>[
  {
    'id': 1,
    'titulo': 'Bolo de cenoura',
    'descricao': 'Receita de bolo de cenoura',
    'tempo_preparo': 0,
    'porcoes': 0,
    'dificuldade': 0,
    'data_cadastro': '2025-03-10T15:20:00.000',
    'categoria_id': 2,
    'imagem': 'assets/images/bolo.png',
  },
  {
    // banco na versão 1: sem a coluna imagem
    'id': 2,
    'titulo': '  ',
    'descricao': null,
    'tempo_preparo': null,
    'porcoes': null,
    'dificuldade': null,
    'data_cadastro': '2025-04-01T08:00:00.000',
    'categoria_id': 9,
  },
];

final _ingredientes = <Map<String, Object?>>[
  {'id': 10, 'nome': 'ovo', 'quantidade': 3, 'unidade_medida': 'un', 'receita_id': 1},
  {'id': 11, 'nome': 'cenoura', 'quantidade': 2.5, 'unidade_medida': 'un', 'receita_id': 1},
  {'id': 12, 'nome': 'perdido', 'quantidade': 1.0, 'unidade_medida': 'g', 'receita_id': 99},
];

final _passos = <Map<String, Object?>>[
  {'id': 20, 'ordem': 2, 'descricao': 'Assar', 'receita_id': 1, 'feito': 0},
  {'id': 21, 'ordem': 1, 'descricao': 'Bater', 'receita_id': 1, 'feito': 1},
];

void main() {
  test('monta as receitas com ingredientes por nome e passos por ordem', () {
    final receitas = receitasDoBancoAntigo(
      receitas: _receitas,
      ingredientes: _ingredientes,
      passos: _passos,
    );

    expect(receitas, hasLength(2));
    final bolo = receitas.first;
    expect(bolo.id, idMigrado(1, DateTime.parse('2025-03-10T15:20:00.000')));
    expect(bolo.titulo, 'Bolo de cenoura');
    expect(bolo.categoriaId, 2);
    expect(bolo.imagem, 'assets/images/bolo.png');
    expect(bolo.dataCadastro, DateTime.parse('2025-03-10T15:20:00.000'));
    expect(bolo.ingredientes.map((i) => i.nome), ['cenoura', 'ovo']);
    expect(bolo.ingredientes.last.quantidade, 3.0);
    expect(bolo.passos.map((p) => p.descricao), ['Bater', 'Assar']);
    expect(bolo.passos.first.feito, isTrue);
  });

  test('corrige o que as regras do Firestore recusariam', () {
    final receitas = receitasDoBancoAntigo(
      receitas: [
        ..._receitas,
        {'id': 3, 'titulo': 'x' * 300, 'data_cadastro': 'data inválida', 'categoria_id': 1},
        {'id': null, 'titulo': 'sem id'},
      ],
      ingredientes: _ingredientes,
      passos: [
        for (var i = 0; i < 250; i++)
          {'ordem': i + 1, 'descricao': 'p$i', 'receita_id': 3, 'feito': 0},
      ],
    );

    expect(receitas, hasLength(3)); // a linha sem id é ignorada
    final semTitulo = receitas[1];
    expect(semTitulo.titulo, tituloPadrao);
    expect(semTitulo.descricao, '');
    expect(semTitulo.categoriaId, 1); // categoria 9 não existe
    expect(semTitulo.imagem, isNull);
    expect(semTitulo.ingredientes, isEmpty);

    final longa = receitas[2];
    expect(longa.titulo.length, tituloMaxLength);
    expect(longa.dataCadastro, DateTime.fromMillisecondsSinceEpoch(0));
    expect(longa.passos, hasLength(itensMaxPorLista));
    for (final receita in receitas) {
      expect(problemaNaReceita(receita), isNull, reason: receita.titulo);
    }
  });

  test('copiar de novo não duplica (ids determinísticos)', () async {
    final repo = ReceitaRepository(firestore: FakeFirebaseFirestore(), uid: 'u1');
    List<String> copiar() => [
      for (final receita in receitasDoBancoAntigo(
        receitas: _receitas,
        ingredientes: _ingredientes,
        passos: _passos,
      ))
        repo.save(receita),
    ];

    final primeira = copiar();
    final segunda = copiar();

    expect(segunda, primeira);
    expect(await repo.getAll(), hasLength(2));
  });
}
