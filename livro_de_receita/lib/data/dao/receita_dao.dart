import 'dart:io';

import 'package:livro_de_receita/data/db_provider.dart';
import 'package:livro_de_receita/models/receita.dart';
import 'package:livro_de_receita/data/dao/ingrediente_dao.dart';
import 'package:livro_de_receita/data/dao/passo_preparo_dao.dart';

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

  static Future<Receita?> getById(int id) async {
    final db = await DBProvider().database;
    final maps = await db.query('receita', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Receita.fromMap(maps.first);
  }

  static Future<int> update(Receita r) async {
    final db = await DBProvider().database;
    if (r.id == null) {
      throw Exception('ID da receita não encontrado para update');
    }
    final data = Map<String, dynamic>.from(r.toMap());
    data.remove('id');
    return db.update('receita', data, where: 'id = ?', whereArgs: [r.id]);
  }

  static Future delete(int id) async {
    final db = await DBProvider().database;
    // Recupera a receita antes de apagar para obter o path da imagem
    String? imagemPath;
    try {
      final receita = await getById(id);
      imagemPath = receita?.imagem;
    } catch (e) {
      imagemPath = null;
    }

    try {
      // Primeiro deleta todos os ingredientes da receita
      await IngredienteDao.deleteByReceita(id);
      // Depois deleta todos os passos de preparo da receita
      await PassoPreparoDao.deleteByReceita(id);
    } catch (e) {
      // Ignora erros ao deletar dados relacionados
    }

    final rows = await db.delete('receita', where: 'id = ?', whereArgs: [id]);

    // Se havia uma imagem localizada fora dos assets, tenta removê-la do disco
    if (imagemPath != null && imagemPath.isNotEmpty && !imagemPath.startsWith('assets/')) {
      try {
        final f = File(imagemPath);
        if (await f.exists()) await f.delete();
      } catch (e) {
        // Falha ao apagar o ficheiro — não interrompe a operação de remoção
      }
    }

    return rows;
  }
}
