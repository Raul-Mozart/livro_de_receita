// Modelo de dados para representar um ingrediente de receita
class Ingrediente {
  String nome;
  double quantidade;
  String unidadeMedida;

  // Construtor
  Ingrediente({
    required this.nome,
    required this.quantidade,
    required this.unidadeMedida,
  });

  // Converte o objeto Ingrediente para um Map (usado para salvar no banco)
  Map<String, dynamic> toMap() => {
        'nome': nome,
        'quantidade': quantidade,
        'unidadeMedida': unidadeMedida,
      };

  // Cria um objeto Ingrediente a partir de um Map (usado para ler do banco)
  factory Ingrediente.fromMap(Map<String, dynamic> m) => Ingrediente(
        nome: (m['nome'] as String?) ?? '',
        quantidade: (m['quantidade'] as num?)?.toDouble() ?? 0,
        unidadeMedida: (m['unidadeMedida'] as String?) ?? '',
      );
}
