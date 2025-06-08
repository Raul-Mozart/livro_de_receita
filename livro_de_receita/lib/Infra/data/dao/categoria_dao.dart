import '../db_provider.dart';
import '../../models/categoria.dart';

// Classe responsável pelas operações de banco de dados da tabela categoria
class CategoriaDao {
  static Future<List<Categoria>> getAll() async {
    
    final db = await DBProvider().database;
    final maps = await db.query('categoria', orderBy: 'nome');

    // Converte os Maps retornados em objetos Categoria e retorna a lista
    return maps.map((m) => Categoria.fromMap(m)).toList();
  }
}
