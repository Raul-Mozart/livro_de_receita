// Modelo de dados para representar um passo de preparo de receita
class PassoPreparo {
  int? id;
  int ordem;
  String descricao;
  int receitaId;
  bool feito;
  
  // Construtor
  PassoPreparo({
    this.id,
    required this.ordem,
    required this.descricao,
    required this.receitaId,
    required this.feito,
  });
  
  // Converte o objeto PassoPreparo para um Map (usado para salvar no banco)
  Map<String, dynamic> toMap() => {
        'id': id,
        'ordem': ordem,
        'descricao': descricao,
        'receita_id': receitaId,
        'feito': feito ? 1 : 0,
      };
  
  // Cria um objeto PassoPreparo a partir de um Map (usado para ler do banco)
  factory PassoPreparo.fromMap(Map<String, dynamic> m) => PassoPreparo(
        id: m['id'],
        ordem: m['ordem'],
        descricao: m['descricao'],
        receitaId: m['receita_id'],
        feito: m['feito'] == 1 || m['feito'] == true, 
      );
  
  // Método para criar uma cópia do objeto com alguns valores alterados
  PassoPreparo copyWith({
    int? id,
    int? ordem,
    String? descricao,
    int? receitaId,
    bool? feito,
  }) {
    return PassoPreparo(
      id: id ?? this.id, // Usa o novo valor ou mantém o atual
      ordem: ordem ?? this.ordem,
      descricao: descricao ?? this.descricao,
      receitaId: receitaId ?? this.receitaId,
      feito: feito ?? this.feito,
    );
  }
}
