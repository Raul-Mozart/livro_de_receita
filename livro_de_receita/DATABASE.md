# 🗄️ Como Funciona o Banco de Dados - Livro de Receitas

Este guia explica **passo a passo** como o banco de dados SQLite funciona no aplicativo **Livro de Receitas**, com exemplos práticos de código.

## 📋 Passo a Passo
- [Como o banco é criado](#-passo-1-como-o-banco-é-criado)
- [Como as tabelas são organizadas](#-passo-2-como-as-tabelas-são-organizadas)
- [Como salvar uma receita](#-passo-3-como-salvar-uma-receita)
- [Como buscar receitas](#-passo-4-como-buscar-receitas)
- [Como editar e excluir](#-passo-5-como-editar-e-excluir)
- [Como funciona na prática](#-passo-6-como-funciona-na-prática)

---

## 📱 Passo 1: Como o banco é criado

### O que acontece quando você abre o app?

Quando você abre o aplicativo pela primeira vez, o código faz isso:

```dart
// No arquivo db_provider.dart
class DBProvider {
  // Cria uma conexão única com o banco de dados
  Future<Database> get database async {
    _db = await openDatabase(
      'receitas.db',        // Nome do arquivo no celular
      version: 2,           // Versão do banco (para atualizações)
      onCreate: _onCreate,  // Cria as tabelas se não existem
    );
    return _db;
  }
}
```

### Criando as tabelas pela primeira vez

O método `_onCreate` roda **apenas na primeira vez** e cria 4 tabelas:

```sql
-- 1. Tabela de categorias (Salgados, Doces, Bebidas)
CREATE TABLE categoria (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL
)

-- 2. Tabela principal de receitas
CREATE TABLE receita (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  titulo TEXT,
  descricao TEXT,
  tempo_preparo INTEGER,
  porcoes INTEGER,
  dificuldade INTEGER,
  data_cadastro TEXT,
  categoria_id INTEGER,
  imagem TEXT
)

-- 3. Tabela de ingredientes
CREATE TABLE ingrediente (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT,
  quantidade REAL,
  unidade_medida TEXT,
  receita_id INTEGER
)

-- 4. Tabela de passos de preparo
CREATE TABLE passo_preparo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ordem INTEGER,
  descricao TEXT,
  receita_id INTEGER,
  feito BOOLEAN
)
```

**O que isso significa?**
- O banco fica salvo no seu celular no arquivo `receitas.db`
- Cada tabela tem um `id` único que aumenta sozinho (1, 2, 3...)
- As receitas são conectadas com categorias, ingredientes e passos

---

## 🗂️ Passo 2: Como as tabelas são organizadas

### Pensando em uma receita de Bolo de Chocolate

Vamos imaginar que você quer salvar esta receita:
- **Categoria**: Doces
- **Título**: Bolo de Chocolate
- **Ingredientes**: Farinha, Açúcar, Ovos
- **Passos**: Misturar, Assar

### Como fica salvo no banco:

**Tabela `categoria`:**
```
| id | nome    |
|----|---------|
| 1  | Salgados|
| 2  | Doces   | ← Nossa categoria
| 3  | Bebidas |
```

**Tabela `receita`:**
```
| id | titulo         | categoria_id | tempo_preparo | porcoes |
|----|----------------|--------------|---------------|---------|
| 1  | Bolo de Chocolate | 2          | 60           | 8       |
```

**Tabela `ingrediente`:**
```
| id | nome     | quantidade | unidade_medida | receita_id |
|----|----------|------------|----------------|------------|
| 1  | Farinha  | 2.0        | xícaras        | 1          |
| 2  | Açúcar   | 1.5        | xícaras        | 1          |
| 3  | Ovos     | 3.0        | unidades       | 1          |
```

**Tabela `passo_preparo`:**
```
| id | ordem | descricao              | receita_id | feito |
|----|-------|------------------------|------------|-------|
| 1  | 1     | Misture ingredientes   | 1          | false |
| 2  | 2     | Asse por 40 minutos    | 1          | false |
```

**Entendeu?** Todas as tabelas se conectam pelo `id` da receita!

---

## 💾 Passo 3: Como salvar uma receita

### No app: Quando você preenche o formulário

Quando você vai em "Adicionar Receita" e preenche os campos, isso acontece:

```dart
// No arquivo cadastro.dart
_salvar() async {
  // 1. Primeiro salva a receita principal
  Receita novaReceita = Receita(
    titulo: _tituloController.text,           // "Bolo de Chocolate"
    descricao: _descricaoController.text,     // "Delicioso bolo..."
    tempoPreparo: int.parse(_tempoController.text), // 60
    porcoes: int.parse(_porcoesController.text),    // 8
    dificuldade: _dificuldade,                // 3
    dataCadastro: DateTime.now(),             // Data de hoje
    categoriaId: _categoriaSelecionada?.id,   // 2 (Doces)
    imagem: _imagemSelecionada,               // "bolo.png"
  );

  // Salva no banco e pega o ID gerado
  int receitaId = await ReceitaDao.insert(novaReceita);
}
```

### Como funciona o `ReceitaDao.insert()`:

```dart
// No arquivo receita_dao.dart
static Future<int> insert(Receita receita) async {
  // Pega a conexão com o banco
  final db = await DBProvider().database;
  
  // Converte a receita em um Map (dicionário)
  Map<String, dynamic> dados = {
    'titulo': 'Bolo de Chocolate',
    'descricao': 'Delicioso bolo...',
    'tempo_preparo': 60,
    'porcoes': 8,
    'dificuldade': 3,
    'data_cadastro': '2024-01-15T10:30:00.000',
    'categoria_id': 2,
    'imagem': 'bolo.png'
  };
  
  // Faz o INSERT no banco
  return await db.insert('receita', dados);
  // Retorna o ID gerado (ex: 1)
}
```

### Salvando ingredientes:

```dart
// Para cada ingrediente digitado
for (var ingrediente in _ingredientes) {
  await IngredienteDao.insert(Ingrediente(
    nome: ingrediente.nome,           // "Farinha"
    quantidade: ingrediente.quantidade, // 2.0
    unidadeMedida: ingrediente.unidadeMedida, // "xícaras"
    receitaId: receitaId,            // 1 (conecta com a receita)
  ));
}
```

### Salvando passos:

```dart
// Para cada passo digitado
for (int i = 0; i < _passos.length; i++) {
  await PassoPreparoDao.insert(PassoPreparo(
    ordem: i + 1,                    // 1, 2, 3...
    descricao: _passos[i].descricao, // "Misture ingredientes"
    receitaId: receitaId,            // 1 (conecta com a receita)
    feito: false,                    // Ainda não foi feito
  ));
}
```

**Resultado:** Uma receita completa salva em 4 tabelas conectadas!

---

## 🔍 Passo 4: Como buscar receitas

### Na tela inicial: Lista de receitas

Quando você abre o app, ele mostra todas as receitas. Veja como:

```dart
// No arquivo categoria_page.dart
_carregarReceitas() async {
  // Busca todas as receitas no banco
  List<Receita> todasReceitas = await ReceitaDao.getAll();
  
  setState(() {
    _receitas = todasReceitas; // Atualiza a lista na tela
  });
}
```

### Como o `ReceitaDao.getAll()` funciona:

```dart
// No arquivo receita_dao.dart
static Future<List<Receita>> getAll() async {
  // Conecta com o banco
  final db = await DBProvider().database;
  
  // Faz um SELECT ordenado por título
  final maps = await db.query('receita', orderBy: 'titulo');
  
  // Converte cada linha em um objeto Receita
  return maps.map((linha) => Receita.fromMap(linha)).toList();
}
```

**O que acontece:**
1. O banco retorna uma lista de "mapas" (como dicionários)
2. Cada mapa vira um objeto `Receita`
3. A lista é mostrada na tela

### Quando você clica em uma receita:

```dart
// No arquivo recipe_details.dart
_carregarDetalhes() async {
  // Busca ingredientes da receita
  _ingredientes = await IngredienteDao.getAllByReceita(widget.receita.id);
  
  // Busca passos da receita
  _passos = await PassoPreparoDao.getAllByReceita(widget.receita.id);
  
  setState(() {}); // Atualiza a tela
}
```

### Como busca ingredientes de UMA receita:

```dart
// No arquivo ingrediente_dao.dart
static Future<List<Ingrediente>> getAllByReceita(int receitaId) async {
  final db = await DBProvider().database;
  
  // SELECT apenas dos ingredientes desta receita
  final maps = await db.query(
    'ingrediente',
    where: 'receita_id = ?',    // Filtra pela receita
    whereArgs: [receitaId],     // receita_id = 1
    orderBy: 'nome'             // Ordena por nome
  );
  
  return maps.map((m) => Ingrediente.fromMap(m)).toList();
}
```

**Explicando o SQL:**
- `where: 'receita_id = ?'` significa "apenas ingredientes da receita X"
- `whereArgs: [receitaId]` substitui o `?` pelo ID da receita
- `orderBy: 'nome'` coloca os ingredientes em ordem alfabética

---

## ✏️ Passo 5: Como editar e excluir

### Editando uma receita

Quando você clica em "Editar" (se existir), o app carrega os dados atuais:

```dart
// Carrega dados para edição
_tituloController.text = receita.titulo;        // "Bolo de Chocolate"
_descricaoController.text = receita.descricao;  // "Delicioso bolo..."
_tempoController.text = receita.tempoPreparo.toString(); // "60"
```

Para salvar as mudanças:

```dart
// Atualiza a receita no banco
static Future<int> update(Receita receita) async {
  final db = await DBProvider().database;
  
  return await db.update(
    'receita',                    // Tabela
    receita.toMap(),              // Novos dados
    where: 'id = ?',              // Condição
    whereArgs: [receita.id],      // ID da receita
  );
}
```

### Excluindo uma receita

Quando você exclui uma receita, **tem que excluir tudo relacionado**:

```dart
// No arquivo receita_dao.dart
static Future delete(int id) async {
  final db = await DBProvider().database;
  
  try {
    // 1. Exclui ingredientes primeiro
    await IngredienteDao.deleteByReceita(id);
    
    // 2. Exclui passos
    await PassoPreparoDao.deleteByReceita(id);
  } catch (e) {
    // Se der erro, ignora (pode não ter ingredientes)
  }
  
  // 3. Por último, exclui a receita
  return db.delete('receita', where: 'id = ?', whereArgs: [id]);
}
```

**Por que essa ordem?**
- Se você excluir a receita primeiro, os ingredientes ficam "órfãos"
- Excluindo ingredientes e passos primeiro, depois a receita, tudo fica limpo

### Como excluir ingredientes de uma receita:

```dart
// No arquivo ingrediente_dao.dart
static Future<int> deleteByReceita(int receitaId) async {
  final db = await DBProvider().database;
  
  // DELETE WHERE receita_id = ?
  return await db.delete(
    'ingrediente',
    where: 'receita_id = ?',
    whereArgs: [receitaId],
  );
}
```

---

## 🎯 Passo 6: Como funciona na prática

### Fluxo completo: Adicionando uma receita de Pão

1. **Usuário preenche o formulário:**
   - Título: "Pão Caseiro"
   - Categoria: "Salgados" (id = 1)
   - Ingredientes: Farinha, Fermento, Sal
   - Passos: Misturar, Sovar, Assar

2. **App salva no banco:**
   ```sql
   -- Salva receita principal
   INSERT INTO receita (titulo, categoria_id, ...) VALUES ('Pão Caseiro', 1, ...);
   -- Retorna ID = 2
   
   -- Salva ingredientes
   INSERT INTO ingrediente (nome, receita_id) VALUES ('Farinha', 2);
   INSERT INTO ingrediente (nome, receita_id) VALUES ('Fermento', 2);
   INSERT INTO ingrediente (nome, receita_id) VALUES ('Sal', 2);
   
   -- Salva passos
   INSERT INTO passo_preparo (ordem, descricao, receita_id) VALUES (1, 'Misturar', 2);
   INSERT INTO passo_preparo (ordem, descricao, receita_id) VALUES (2, 'Sovar', 2);
   INSERT INTO passo_preparo (ordem, descricao, receita_id) VALUES (3, 'Assar', 2);
   ```

3. **Usuário vê na lista:**
   - App faz `SELECT * FROM receita ORDER BY titulo`
   - Mostra: "Bolo de Chocolate", "Pão Caseiro"

4. **Usuário clica em "Pão Caseiro":**
   - App faz `SELECT * FROM ingrediente WHERE receita_id = 2`
   - App faz `SELECT * FROM passo_preparo WHERE receita_id = 2 ORDER BY ordem`
   - Mostra tudo organizado na tela

### Como marcar um passo como feito:

```dart
// Quando usuário marca checkbox
static Future<int> updateFeito(int id, bool feito) async {
  final db = await DBProvider().database;
  
  return await db.update(
    'passo_preparo',
    {'feito': feito ? 1 : 0},  // SQLite usa 1/0 para true/false
    where: 'id = ?',
    whereArgs: [id],
  );
}
```