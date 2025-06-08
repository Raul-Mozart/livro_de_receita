import '../db_provider.dart';
import '../../models/ingrediente.dart';

// Classe responsável pelas operações de banco de dados da tabela ingrediente
class IngredienteDao {
  static Future<int> insert(Ingrediente i) async {
    final db = await DBProvider().database;
    return db.insert('ingrediente', i.toMap());
  }

  static Future<List<Ingrediente>> getAllByReceita(int receitaId) async {
    // Obtém a conexão com o banco de dados
    final db = await DBProvider().database;
    final maps = await db.query(
      'ingrediente',
      where: 'receita_id = ?', 
      whereArgs: [receitaId],
      orderBy: 'nome', 
    );
    return maps.map((m) => Ingrediente.fromMap(m)).toList();
  }

  
  static Future<int> deleteByReceita(int receitaId) async {
    // Obtém a conexão com o banco de dados
    final db = await DBProvider().database;
    return db.delete(
      'ingrediente',
      where: 'receita_id = ?', 
      whereArgs: [receitaId],
    );
  }
}
