// Modelo de dados para representar uma categoria de receita
class Categoria {
  int? id;
  String nome;
    Categoria({this.id, required this.nome});
  
  // Converte o objeto Categoria para um Map (usado para salvar no banco)
  Map<String, dynamic> toMap() => {'id': id, 'nome': nome};
  
  // Cria um objeto Categoria a partir de um Map (usado para ler do banco)
  factory Categoria.fromMap(Map<String, dynamic> m) =>
      Categoria(id: m['id'], nome: m['nome']);
}
