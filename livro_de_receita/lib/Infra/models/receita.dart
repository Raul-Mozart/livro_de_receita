// Modelo de dados para representar uma receita completa
class Receita {
  int? id;
  String titulo;
  String descricao;
  int tempoPreparo;
  int porcoes;
  int dificuldade;
  DateTime dataCadastro;
  int categoriaId;
  String? imagem;
  
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
  });
  
  // Converte o objeto Receita para um Map (usado para salvar no banco)
  Map<String, dynamic> toMap() => {
        'id': id,
        'titulo': titulo,
        'descricao': descricao,
        'tempo_preparo': tempoPreparo,
        'porcoes': porcoes,
        'dificuldade': dificuldade,
        'data_cadastro': dataCadastro.toIso8601String(),
        'categoria_id': categoriaId,
        'imagem': imagem,
      };
  
  // Cria um objeto Receita a partir de um Map (usado para ler do banco)
  factory Receita.fromMap(Map<String, dynamic> m) => Receita(
        id: m['id'],
        titulo: m['titulo'],
        descricao: m['descricao'],
        tempoPreparo: m['tempo_preparo'],
        porcoes: m['porcoes'],
        dificuldade: m['dificuldade'],
        dataCadastro: DateTime.parse(m['data_cadastro']), // Converte String para DateTime
        categoriaId: m['categoria_id'],
        imagem: m['imagem'],
      );
}
