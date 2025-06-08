import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Classe responsável pela criação e gerenciamento do banco de dados SQLite
class DBProvider {
  // Implementa padrão Singleton - garante uma única instância da classe
  static final DBProvider _instance = DBProvider._();
  static Database? _db;
  
  DBProvider._();
  
  factory DBProvider() => _instance;
  
  Future<Database> get database async {
    // Se o banco já foi inicializado, retorna a instância existente
    if (_db != null) return _db!;
    
    // Cria o caminho completo para o arquivo do banco de dados
    final path = join(await getDatabasesPath(), 'receitas.db');
    
    // Abre/cria o banco de dados
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate, 
      onUpgrade: _onUpgrade,
    );
    
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL
      );''');
    
    await db.execute('''
      CREATE TABLE receita (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT,
        descricao TEXT,
        tempo_preparo INTEGER,
        porcoes INTEGER,
        dificuldade INTEGER,
        data_cadastro TEXT,
        categoria_id INTEGER,
        imagem TEXT,
        FOREIGN KEY (categoria_id) REFERENCES categoria(id)
      );''');
    
    await db.execute('''
      CREATE TABLE ingrediente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT,
        quantidade REAL,
        unidade_medida TEXT,
        receita_id INTEGER,
        FOREIGN KEY (receita_id) REFERENCES receita(id)
      );''');
    
    await db.execute('''
      CREATE TABLE passo_preparo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ordem INTEGER,
        descricao TEXT,
        receita_id INTEGER,
        feito BOOLEAN,
        FOREIGN KEY (receita_id) REFERENCES receita(id)
      );''');
    
    await db.insert('categoria', {'nome': 'Salgados'});
    await db.insert('categoria', {'nome': 'Doces'});
    await db.insert('categoria', {'nome': 'Bebidas'});
  }

  // Método chamado quando há necessidade de atualizar o banco para nova versão
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE receita ADD COLUMN imagem TEXT;');
    }
  }
}
