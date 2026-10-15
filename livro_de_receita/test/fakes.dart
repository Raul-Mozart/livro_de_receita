import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:livro_de_receita/data/auth_service.dart';
import 'package:livro_de_receita/data/receita_repository.dart';
import 'package:livro_de_receita/models/ingrediente.dart';
import 'package:livro_de_receita/models/passo_preparo.dart';
import 'package:livro_de_receita/models/receita.dart';

// Login falso: guarda as chamadas e emite o UID como o Firebase Auth faria
class FakeAuthService implements AuthService {
  FakeAuthService({this.uidInicial, this.email});

  final String? uidInicial;
  String? email;
  final List<String> chamadas = [];
  AuthFailure? falha;
  final _uids = StreamController<String?>.broadcast();

  @override
  Stream<String?> uidChanges() async* {
    yield uidInicial;
    yield* _uids.stream;
  }

  void emitir(String? uid) => _uids.add(uid);

  @override
  String? get currentEmail => email;

  @override
  Future<void> signIn(String email, String password) async {
    chamadas.add('signIn:$email:$password');
    if (falha != null) throw falha!;
  }

  @override
  Future<void> register(String email, String password) async {
    chamadas.add('register:$email:$password');
    if (falha != null) throw falha!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    chamadas.add('reset:$email');
    if (falha != null) throw falha!;
  }

  @override
  Future<void> signOut() async {
    chamadas.add('signOut');
    emitir(null);
  }
}

// Repositório sobre o Firestore falso, sem gravações pendentes
class RepositorioDeTeste extends ReceitaRepository {
  RepositorioDeTeste({super.uid = 'u1', FakeFirebaseFirestore? firestore})
    : super(firestore: firestore ?? FakeFirebaseFirestore());

  @override
  Future<bool> waitForPendingWrites({Duration timeout = const Duration(seconds: 5)}) async =>
      true;
}

Receita receitaExemplo({
  String? id,
  String titulo = 'Bolo de cenoura',
  int categoriaId = 2,
  String? imagem,
}) => Receita(
  id: id,
  titulo: titulo,
  descricao: 'Receita de ${titulo.toLowerCase()}',
  tempoPreparo: 40,
  porcoes: 8,
  dificuldade: 2,
  dataCadastro: DateTime.utc(2026, 10, 14, 12),
  categoriaId: categoriaId,
  imagem: imagem,
  ingredientes: [
    Ingrediente(nome: 'cenoura', quantidade: 3, unidadeMedida: 'un'),
    Ingrediente(nome: 'açúcar', quantidade: 1.5, unidadeMedida: 'xícara'),
  ],
  passos: [
    PassoPreparo(ordem: 1, descricao: 'Bater a cenoura', feito: false),
    PassoPreparo(ordem: 2, descricao: 'Assar por 40 minutos', feito: false),
  ],
);
