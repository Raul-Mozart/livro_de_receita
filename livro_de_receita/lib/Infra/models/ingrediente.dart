// Modelo de dados para representar um ingrediente de receita
class Ingrediente {
  int? id;
  String nome;
  double quantidade;
  String unidadeMedida;
  int receitaId;
  
  // Construtor
  Ingrediente({
    this.id,
    required this.nome,
    required this.quantidade,
    required this.unidadeMedida,
    required this.receitaId,
  });
  
  // Converte o objeto Ingrediente para um Map (usado para salvar no banco)
  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'quantidade': quantidade,
        'unidade_medida': unidadeMedida,
        'receita_id': receitaId,
      };
  
  // Cria um objeto Ingrediente a partir de um Map (usado para ler do banco)
  factory Ingrediente.fromMap(Map<String, dynamic> m) => Ingrediente(
        id: m['id'],
        nome: m['nome'],
        quantidade: m['quantidade'],
        unidadeMedida: m['unidade_medida'],
        receitaId: m['receita_id'],
      );
  
  // Método para criar uma cópia do objeto com alguns valores alterados
  Ingrediente copyWith({
    int? id,
    String? nome,
    double? quantidade,
    String? unidadeMedida,
    int? receitaId,
  }) {
    return Ingrediente(
      id: id ?? this.id, // Usa o novo valor ou mantém o atual
      nome: nome ?? this.nome,
      quantidade: quantidade ?? this.quantidade,
      unidadeMedida: unidadeMedida ?? this.unidadeMedida,
      receitaId: receitaId ?? this.receitaId,
    );
  }
}
