import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:livro_de_receita/models/categoria.dart';
import 'package:livro_de_receita/models/ingrediente.dart';
import 'package:livro_de_receita/models/passo_preparo.dart';
import 'package:livro_de_receita/models/receita.dart';

// Limites que também estão em firebase/firestore.rules (manter os dois iguais)
const int tituloMaxLength = 200;
const int descricaoMaxLength = 2000;
const int imagemMaxLength = 2048;
const int itensMaxPorLista = 200;

// Receita fora dos limites aceitos pelas regras do Firestore
class ReceitaInvalida implements Exception {
  final String mensagem;
  const ReceitaInvalida(this.mensagem);

  @override
  String toString() => mensagem;
}

// Devolve o problema da receita (texto para o usuário) ou null se ela pode ser gravada
String? problemaNaReceita(Receita r) {
  final titulo = r.titulo.trim();
  if (titulo.isEmpty) return 'O nome da receita é obrigatório.';
  if (titulo.length > tituloMaxLength) {
    return 'O nome da receita pode ter no máximo $tituloMaxLength caracteres.';
  }
  if (r.descricao.length > descricaoMaxLength) {
    return 'A descrição pode ter no máximo $descricaoMaxLength caracteres.';
  }
  if (Categoria.porId(r.categoriaId) == null) return 'Selecione uma categoria válida.';
  if ((r.imagem?.length ?? 0) > imagemMaxLength) return 'Caminho da imagem longo demais.';
  if (r.ingredientes.length > itensMaxPorLista) {
    return 'A receita pode ter no máximo $itensMaxPorLista ingredientes.';
  }
  if (r.passos.length > itensMaxPorLista) {
    return 'A receita pode ter no máximo $itensMaxPorLista passos.';
  }
  return null;
}

// Converte a receita para o documento do Firestore (o id é o nome do documento, não um campo)
Map<String, dynamic> receitaToFirestore(Receita r) => {
      'titulo': r.titulo.trim(),
      'descricao': r.descricao,
      'tempoPreparo': r.tempoPreparo,
      'porcoes': r.porcoes,
      'dificuldade': r.dificuldade,
      'dataCadastro': Timestamp.fromDate(r.dataCadastro),
      'categoriaId': r.categoriaId,
      'imagem': r.imagem,
      'ingredientes': r.ingredientes.map((i) => i.toMap()).toList(),
      'passos': r.passos.map((p) => p.toMap()).toList(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

// Converte o documento do Firestore em receita; campos ausentes recebem valores neutros
Receita receitaFromFirestore(String id, Map<String, dynamic> d) {
  final data = d['dataCadastro'];
  final passos = ((d['passos'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => PassoPreparo.fromMap(Map<String, dynamic>.from(m)))
      .toList()
    ..sort((a, b) => a.ordem.compareTo(b.ordem));
  return Receita(
    id: id,
    titulo: (d['titulo'] as String?) ?? '',
    descricao: (d['descricao'] as String?) ?? '',
    tempoPreparo: (d['tempoPreparo'] as num?)?.toInt() ?? 0,
    porcoes: (d['porcoes'] as num?)?.toInt() ?? 0,
    dificuldade: (d['dificuldade'] as num?)?.toInt() ?? 0,
    dataCadastro: data is Timestamp ? data.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
    categoriaId: (d['categoriaId'] as num?)?.toInt() ?? 1,
    imagem: d['imagem'] as String?,
    ingredientes: ((d['ingredientes'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Ingrediente.fromMap(Map<String, dynamic>.from(m)))
        .toList(),
    passos: passos,
  );
}

// Foto tirada no aparelho (não é imagem do app nem endereço da web)
bool isFotoLocal(String? imagem) =>
    imagem != null &&
    imagem.isNotEmpty &&
    !imagem.startsWith('assets/') &&
    !imagem.startsWith('http://') &&
    !imagem.startsWith('https://');

// Receitas do usuário no Firestore: users/{uid}/receitas/{id}.
// Lê e grava no banco local do Firestore; o próprio Firestore envia para a nuvem quando há conexão.
class ReceitaRepository {
  ReceitaRepository({
    required FirebaseFirestore firestore,
    required this.uid,
    this.serverTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final String uid;
  // Sem resposta do servidor nesse tempo, a leitura usa o que já está no aparelho
  final Duration serverTimeout;

  // Repositório do usuário conectado (definido no login, como os antigos DAOs estáticos)
  static ReceitaRepository? _atual;

  static ReceitaRepository get atual {
    final repo = _atual;
    if (repo == null) throw StateError('Nenhum usuário conectado');
    return repo;
  }

  static void conectar(ReceitaRepository repo) => _atual = repo;

  static void desconectar() => _atual = null;

  CollectionReference<Map<String, dynamic>> get _receitas =>
      _firestore.collection('users').doc(uid).collection('receitas');

  // Todas as receitas, em ordem de título
  Future<List<Receita>> getAll() async {
    final query = _receitas.orderBy('titulo');
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.get().timeout(serverTimeout);
    } on TimeoutException {
      snap = await query.get(const GetOptions(source: Source.cache));
    }
    return snap.docs.map((doc) => receitaFromFirestore(doc.id, doc.data())).toList();
  }

  // Receita pelo id; null se não existe (ou se está offline e ela nunca veio para o aparelho)
  Future<Receita?> getById(String id) async {
    final ref = _receitas.doc(id);
    try {
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await ref.get().timeout(serverTimeout);
      } on TimeoutException {
        snap = await ref.get(const GetOptions(source: Source.cache));
      }
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return receitaFromFirestore(snap.id, data);
    } on FirebaseException catch (e) {
      // Offline o Firestore devolve erro quando o documento não está no aparelho
      if (e.code != 'unavailable') rethrow;
      return null;
    }
  }

  // Grava a receita inteira (nova quando id == null) e devolve o id.
  // Não espera o servidor: offline a confirmação só chega quando a conexão volta.
  String save(Receita receita) {
    final problema = problemaNaReceita(receita);
    if (problema != null) throw ReceitaInvalida(problema);
    final ref = receita.id == null ? _receitas.doc() : _receitas.doc(receita.id);
    _registrarFalha(ref.set(receitaToFirestore(receita)), 'salvar');
    return ref.id;
  }

  // Exclui a receita e a foto tirada no aparelho, se houver
  Future<void> delete(String id, {String? imagem}) async {
    _registrarFalha(_receitas.doc(id).delete(), 'excluir');
    if (isFotoLocal(imagem)) {
      try {
        final arquivo = File(imagem!);
        if (await arquivo.exists()) await arquivo.delete();
      } catch (_) {
        // Falha ao apagar o arquivo da foto não impede a exclusão da receita
      }
    }
  }

  // Espera o envio do que está pendente; false se não terminou no prazo (ex.: sem internet)
  Future<bool> waitForPendingWrites({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await _firestore.waitForPendingWrites().timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  void _registrarFalha(Future<void> gravacao, String operacao) {
    gravacao.catchError((Object e) {
      // Sem dado da receita no log: só a operação e o código do erro
      final codigo = e is FirebaseException ? e.code : e.runtimeType.toString();
      debugPrint('Firestore: falha ao $operacao receita ($codigo)');
    });
  }
}
