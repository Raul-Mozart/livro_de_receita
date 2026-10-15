import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_de_receita/data/receita_repository.dart';
import 'package:livro_de_receita/models/ingrediente.dart';
import 'package:livro_de_receita/models/passo_preparo.dart';

import 'fakes.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReceitaRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = ReceitaRepository(firestore: firestore, uid: 'u1');
  });

  group('receitaToFirestore / receitaFromFirestore', () {
    test('grava os campos do documento sem o id e com o horário do servidor', () {
      final doc = receitaToFirestore(receitaExemplo(id: 'abc', imagem: 'assets/images/bolo.png'));

      expect(doc.containsKey('id'), isFalse);
      expect(doc['titulo'], 'Bolo de cenoura');
      expect(doc['categoriaId'], 2);
      expect(doc['dataCadastro'], Timestamp.fromDate(DateTime.utc(2026, 10, 14, 12)));
      expect(doc['atualizadoEm'], FieldValue.serverTimestamp());
      expect(doc['imagem'], 'assets/images/bolo.png');
      expect(doc['ingredientes'], [
        {'nome': 'cenoura', 'quantidade': 3.0, 'unidadeMedida': 'un'},
        {'nome': 'açúcar', 'quantidade': 1.5, 'unidadeMedida': 'xícara'},
      ]);
      expect(doc['passos'], [
        {'ordem': 1, 'descricao': 'Bater a cenoura', 'feito': false},
        {'ordem': 2, 'descricao': 'Assar por 40 minutos', 'feito': false},
      ]);
    });

    test('lê o documento, ordena os passos e tolera campos ausentes', () {
      final receita = receitaFromFirestore('r1', {
        'titulo': 'Suco',
        'dataCadastro': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        'categoriaId': 3,
        'ingredientes': [
          {'nome': 'laranja', 'quantidade': 4, 'unidadeMedida': 'un'},
        ],
        'passos': [
          {'ordem': 2, 'descricao': 'Coar'},
          {'ordem': 1, 'descricao': 'Espremer', 'feito': true},
        ],
      });

      expect(receita.id, 'r1');
      expect(receita.descricao, '');
      expect(receita.porcoes, 0);
      expect(receita.imagem, isNull);
      // Timestamp.toDate() devolve a hora local: compara o mesmo instante
      expect(receita.dataCadastro.toUtc(), DateTime.utc(2026, 1, 2));
      expect(receita.ingredientes.single.quantidade, 4.0);
      expect(receita.passos.map((p) => p.descricao), ['Espremer', 'Coar']);
      expect(receita.passos.first.feito, isTrue);
      expect(receita.passos.last.feito, isFalse);
    });
  });

  group('problemaNaReceita (mesmos limites das regras do Firestore)', () {
    test('aceita a receita de exemplo', () {
      expect(problemaNaReceita(receitaExemplo()), isNull);
    });

    test('recusa título vazio, título longo e categoria fora do catálogo', () {
      expect(problemaNaReceita(receitaExemplo(titulo: '   ')), isNotNull);
      expect(problemaNaReceita(receitaExemplo(titulo: 'x' * 201)), isNotNull);
      expect(problemaNaReceita(receitaExemplo(titulo: 'x' * 200)), isNull);
      expect(problemaNaReceita(receitaExemplo(categoriaId: 4)), isNotNull);
    });

    test('recusa mais de 200 ingredientes ou passos', () {
      final muitosIngredientes = receitaExemplo()
        ..ingredientes = List.generate(
          201,
          (i) => Ingrediente(nome: 'i$i', quantidade: 1, unidadeMedida: 'g'),
        );
      final muitosPassos = receitaExemplo()
        ..passos = List.generate(
          201,
          (i) => PassoPreparo(ordem: i + 1, descricao: 'p$i', feito: false),
        );
      expect(problemaNaReceita(muitosIngredientes), isNotNull);
      expect(problemaNaReceita(muitosPassos), isNotNull);
    });
  });

  test('isFotoLocal distingue foto do aparelho de imagem do app e endereço web', () {
    expect(isFotoLocal('/data/user/0/app/receitas_images/1.jpg'), isTrue);
    expect(isFotoLocal('assets/images/bolo.png'), isFalse);
    expect(isFotoLocal('https://exemplo.com/foto.jpg'), isFalse);
    expect(isFotoLocal(''), isFalse);
    expect(isFotoLocal(null), isFalse);
  });

  group('ReceitaRepository', () {
    test('save devolve o id na hora e grava em users/{uid}/receitas', () async {
      final id = repo.save(receitaExemplo());

      expect(id, isNotEmpty);
      final doc = await firestore.doc('users/u1/receitas/$id').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['titulo'], 'Bolo de cenoura');
      expect(doc.data()!['atualizadoEm'], isA<Timestamp>());
    });

    test('getById traz a receita com ingredientes e passos', () async {
      final id = repo.save(receitaExemplo());

      final receita = await repo.getById(id);

      expect(receita, isNotNull);
      expect(receita!.id, id);
      expect(receita.ingredientes.map((i) => i.nome), ['cenoura', 'açúcar']);
      expect(receita.passos.map((p) => p.ordem), [1, 2]);
    });

    test('getById devolve null quando a receita não existe', () async {
      expect(await repo.getById('nao-existe'), isNull);
    });

    test('getAll ordena por título e só traz as receitas do usuário', () async {
      repo.save(receitaExemplo(titulo: 'Suco de laranja', categoriaId: 3));
      repo.save(receitaExemplo(titulo: 'Bolo de cenoura'));
      repo.save(receitaExemplo(titulo: 'Coxinha', categoriaId: 1));
      ReceitaRepository(firestore: firestore, uid: 'u2').save(receitaExemplo(titulo: 'Alheia'));

      final receitas = await repo.getAll();

      expect(receitas.map((r) => r.titulo), ['Bolo de cenoura', 'Coxinha', 'Suco de laranja']);
    });

    test('save com id sobrescreve a receita (editar não duplica)', () async {
      final id = repo.save(receitaExemplo());
      final editada = receitaExemplo(id: id, titulo: 'Bolo de laranja')
        ..ingredientes = [Ingrediente(nome: 'laranja', quantidade: 2, unidadeMedida: 'un')];

      expect(repo.save(editada), id);

      final receitas = await repo.getAll();
      expect(receitas, hasLength(1));
      expect(receitas.single.titulo, 'Bolo de laranja');
      expect(receitas.single.ingredientes.single.nome, 'laranja');
    });

    test('save recusa receita inválida sem gravar nada', () async {
      expect(() => repo.save(receitaExemplo(titulo: '')), throwsA(isA<ReceitaInvalida>()));
      expect(await repo.getAll(), isEmpty);
    });

    test('delete remove a receita', () async {
      final id = repo.save(receitaExemplo());

      await repo.delete(id, imagem: 'assets/images/bolo.png');

      expect(await repo.getById(id), isNull);
      expect(await repo.getAll(), isEmpty);
    });

    test('atual exige usuário conectado', () {
      ReceitaRepository.desconectar();
      expect(() => ReceitaRepository.atual, throwsStateError);
      ReceitaRepository.conectar(repo);
      expect(ReceitaRepository.atual, same(repo));
      ReceitaRepository.desconectar();
    });
  });
}
