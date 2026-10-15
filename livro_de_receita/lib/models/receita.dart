import 'package:livro_de_receita/models/ingrediente.dart';
import 'package:livro_de_receita/models/passo_preparo.dart';

// Modelo de dados para representar uma receita completa.
// Ingredientes e passos ficam dentro da receita (um documento no Firestore).
class Receita {
  String? id; // ID do documento no Firestore (null = receita nova)
  String titulo;
  String descricao;
  int tempoPreparo;
  int porcoes;
  int dificuldade;
  DateTime dataCadastro;
  int categoriaId;
  String? imagem;
  List<Ingrediente> ingredientes;
  List<PassoPreparo> passos;

  // Construtor
  Receita({
    this.id,
    required this.titulo,
    required this.descricao,
    required this.tempoPreparo,
    required this.porcoes,
    required this.dificuldade,
    required this.dataCadastro,
    required this.categoriaId,
    this.imagem,
    List<Ingrediente>? ingredientes,
    List<PassoPreparo>? passos,
  }) : ingredientes = ingredientes ?? [],
       passos = passos ?? [];
}
