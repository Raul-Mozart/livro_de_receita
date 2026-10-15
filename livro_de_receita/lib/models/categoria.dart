// Modelo de dados para representar uma categoria de receita
class Categoria {
  final int id;
  final String nome;

  const Categoria({required this.id, required this.nome});

  // Catálogo fixo (os IDs 1, 2 e 3 são usados pela tela inicial e pelas regras do Firestore).
  // Ordem alfabética, como a listagem do banco antigo.
  static const List<Categoria> todas = [
    Categoria(id: 3, nome: 'Bebidas'),
    Categoria(id: 2, nome: 'Doces'),
    Categoria(id: 1, nome: 'Salgados'),
  ];

  static Categoria? porId(int id) {
    for (final categoria in todas) {
      if (categoria.id == id) return categoria;
    }
    return null;
  }
}
