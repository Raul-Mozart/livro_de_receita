import '../db_provider.dart';
import '../../models/receita.dart';
import 'ingrediente_dao.dart';
import 'passo_preparo_dao.dart';

// Classe responsável pelas operações de banco de dados da tabela receita
class ReceitaDao {
  static Future insert(Receita r) async {
    final db = await DBProvider().database;
    // Insere a receita na tabela 'receita' e retorna o ID inserido
    return db.insert('receita', r.toMap());
  }

  static Future<List<Receita>> getAll() async {
    final db = await DBProvider().database;
    final maps = await db.query('receita', orderBy: 'titulo');
    // Converte os Maps retornados em objetos Receita e retorna a lista
    return maps.map((m) => Receita.fromMap(m)).toList();
  }

  static Future delete(int id) async {
    final db = await DBProvider().database;
    try {

      // Primeiro deleta todos os ingredientes da receita
      await IngredienteDao.deleteByReceita(id);
      
      // Depois deleta todos os passos de preparo da receita
      await PassoPreparoDao.deleteByReceita(id);
      
    } catch (e) {
      // Ignora erros ao deletar dados relacionados
    }
    return db.delete('receita', where: 'id = ?', whereArgs: [id]);
  }
}
