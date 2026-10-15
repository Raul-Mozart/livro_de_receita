// Modelo de dados para representar um passo de preparo de receita
class PassoPreparo {
  int ordem;
  String descricao;
  bool feito;

  // Construtor
  PassoPreparo({
    required this.ordem,
    required this.descricao,
    required this.feito,
  });

  // Converte o objeto PassoPreparo para um Map (usado para salvar no banco)
  Map<String, dynamic> toMap() => {
        'ordem': ordem,
        'descricao': descricao,
        'feito': feito,
      };

  // Cria um objeto PassoPreparo a partir de um Map (usado para ler do banco)
  factory PassoPreparo.fromMap(Map<String, dynamic> m) => PassoPreparo(
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
        descricao: (m['descricao'] as String?) ?? '',
        feito: m['feito'] == true || m['feito'] == 1,
      );
}
