import '../db_provider.dart';
import '../../models/passo_preparo.dart';

// Classe responsável pelas operações de banco de dados da tabela passo_preparo
class PassoPreparoDao {
  static Future<int> insert(PassoPreparo p) async {
    // Obtém a conexão com o banco de dados
    final db = await DBProvider().database;
    return db.insert('passo_preparo', p.toMap());
  }

  static Future<List<PassoPreparo>> getAllByReceita(int receitaId) async {
    // Obtém a conexão com o banco de dados
    final db = await DBProvider().database;
    final maps = await db.query(
      'passo_preparo',
      where: 'receita_id = ?',
      whereArgs: [receitaId],
      orderBy: 'ordem', 
    );
    // Converte os Maps retornados em objetos PassoPreparo e retorna a lista
    return maps.map((m) => PassoPreparo.fromMap(m)).toList();
  }

  static Future<int> deleteByReceita(int receitaId) async {
    final db = await DBProvider().database;
    return db.delete(
      'passo_preparo',
      where: 'receita_id = ?', 
      whereArgs: [receitaId],
    );
  }
}
