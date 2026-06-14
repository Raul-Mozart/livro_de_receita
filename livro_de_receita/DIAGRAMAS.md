# 📊 Diagramas UML - Livro de Receitas

## 📐 1. Diagrama de Classes

```mermaid
classDiagram
    direction TB
    class MainApp {
        +build(BuildContext context)
    }

    class LivroDeReceitas {
        -List~Receita~ _salgados
        -List~Receita~ _doces
        -List~Receita~ _bebidas
        -bool _isLoading
        +initState()
        -_carregarReceitas()
        -_navegarParaCategoria()
    }

    class CategoriaPage {
        -int categoriaId
        -String titulo
        -IconData icone
        -List~Receita~ _receitas
        -bool _isLoading
        +initState()
        -_carregarReceitas()
        -_navegarParaDetalhesReceita()
    }

    class RecipeDetailsPage {
        -String title
        -String imageUrl
        -List~String~ ingredients
        -List~String~ instructions
        -int? recipeId
        -List~bool~ _ingredientChecked
        -List~bool~ _instructionChecked
        -SpeechToText _speech
        -FlutterTts _tts
        +initState()
        -_loadRecipeDetails()
        -_initVoiceAssistant()
        -_deleteRecipe()
    }

    class Cadastro {
        -int? recipeId
        -GlobalKey~FormState~ _formKey
        -TextEditingController _nomeController
        -int? _categoriaId
        -String? _imagemAsset
        -List~Ingrediente~ _ingredientes
        -List~PassoPreparo~ _passos
        -List~Categoria~ _categorias
        +initState()
        -_carregarCategorias()
        -_salvarRascunho()
        -_recuperarRascunho()
        -_salvarReceita()
    }

    class Receita {
        -int? id
        -String titulo
        -String descricao
        -int tempoPreparo
        -int porcoes
        -int dificuldade
        -DateTime dataCadastro
        -int categoriaId
        -String? imagem
        +toMap() Map~String, dynamic~
        +fromMap(Map) Receita
    }

    class Categoria {
        -int? id
        -String nome
        +toMap() Map~String, dynamic~
        +fromMap(Map) Categoria
    }

    class Ingrediente {
        -int? id
        -String nome
        -double quantidade
        -String unidadeMedida
        -int receitaId
        +toMap() Map~String, dynamic~
        +fromMap(Map) Ingrediente
        +copyWith() Ingrediente
    }

    class PassoPreparo {
        -int? id
        -int ordem
        -String descricao
        -int receitaId
        -bool feito
        +toMap() Map~String, dynamic~
        +fromMap(Map) PassoPreparo
        +copyWith() PassoPreparo
    }

    class DBProvider {
        -Database? _db
        -DBProvider _instance
        +database Future~Database~
        -_onCreate(Database db, int version)
        -_onUpgrade(Database db, int oldVersion, int newVersion)
    }

    class ReceitaDao {
        +insert(Receita r) static
        +getAll() static List~Receita~
        +getById(int id) static Receita?
        +update(Receita r) static
        +delete(int id) static
    }

    class CategoriaDao {
        +getAll() static List~Categoria~
        +getById(int id) static Categoria?
    }

    class IngredienteDao {
        +insert(Ingrediente i) static
        +getAllByReceita(int receitaId) static List~Ingrediente~
        +deleteByReceita(int receitaId) static
    }

    class PassoPreparoDao {
        +insert(PassoPreparo p) static
        +getAllByReceita(int receitaId) static List~PassoPreparo~
        +deleteByReceita(int receitaId) static
    }

    %% Relacionamentos - Páginas
    MainApp --> LivroDeReceitas
    MainApp --> Cadastro
    LivroDeReceitas --> CategoriaPage
    CategoriaPage --> RecipeDetailsPage
    CategoriaPage --> Cadastro
    RecipeDetailsPage --> Cadastro

    %% Relacionamentos - Modelos
    Receita --> Categoria
    Receita --> Ingrediente
    Receita --> PassoPreparo
    Ingrediente --> Receita
    PassoPreparo --> Receita

    %% Relacionamentos - Persistência
    ReceitaDao --> DBProvider
    CategoriaDao --> DBProvider
    IngredienteDao --> DBProvider
    PassoPreparoDao --> DBProvider
    ReceitaDao --> Receita
    CategoriaDao --> Categoria
    IngredienteDao --> Ingrediente
    PassoPreparoDao --> PassoPreparo

    %% Relacionamentos - Consumo de DAOs pelas Páginas
    LivroDeReceitas --> ReceitaDao
    CategoriaPage --> ReceitaDao
    RecipeDetailsPage --> ReceitaDao
    RecipeDetailsPage --> IngredienteDao
    RecipeDetailsPage --> PassoPreparoDao
    RecipeDetailsPage --> CategoriaDao
    Cadastro --> ReceitaDao
    Cadastro --> IngredienteDao
    Cadastro --> PassoPreparoDao
    Cadastro --> CategoriaDao
```

---

## 🎭 2. Diagrama de Casos de Uso

```mermaid
flowchart LR
    Usuario([Usuario])

    UC1(["Visualizar Receitas<br/>da Tela Inicial"])
    UC2(["Filtrar por Categoria<br/>(Salgados/Doces/Bebidas)"])
    UC3(["Visualizar Detalhes<br/>da Receita"])
    UC4(["Cadastrar<br/>Nova Receita"])
    UC5(["Editar<br/>Receita Existente"])
    UC6(["Deletar<br/>Receita"])
    UC7(["Usar Assistente<br/>de Voz"])
    UC8(["Marcar Ingrediente<br/>Como Verificado"])
    UC9(["Marcar Passo<br/>Como Concluído"])
    UC10(["Selecionar Imagem<br/>da Receita"])
    UC11(["Salvar Rascunho<br/>Auto da Receita"])
    UC12(["Visualizar Histórico<br/>de Unidades"])

    Usuario --> UC1
    UC1 <--> UC2
    UC1 <--> UC3
    UC2 <--> UC3
    UC1 <--> UC4
    UC2 <--> UC4
    UC3 --> UC6
    UC3 --> UC7
    UC3 --> UC8
    UC3 --> UC9
    UC3 --> UC5
    UC4 --> UC10
    UC4 --> UC11
    UC4 --> UC12

```

---

## 🔄 3. Diagrama de Sequência - Fluxo de Cadastro de Receita

```mermaid
sequenceDiagram
    actor Usuario
    participant Cadastro
    participant CategoriaDao
    participant ReceitaDao
    participant IngredienteDao
    participant PassoPreparoDao
    participant DBProvider
    participant SQLite

    Usuario->>Cadastro: Preenche formulário de receita
    Usuario->>Cadastro: Adiciona ingredientes
    Usuario->>Cadastro: Adiciona passos de preparo
    Usuario->>Cadastro: Clica em Salvar
    
    Cadastro->>CategoriaDao: getAll()
    CategoriaDao->>DBProvider: database
    DBProvider->>SQLite: SELECT * FROM categoria
    SQLite-->>DBProvider: Categorias
    DBProvider-->>CategoriaDao: Categorias
    CategoriaDao-->>Cadastro: Categorias
    
    Cadastro->>ReceitaDao: insert(receita)
    ReceitaDao->>DBProvider: database
    DBProvider->>SQLite: INSERT INTO receita VALUES(...)
    SQLite-->>DBProvider: receitaId
    DBProvider-->>ReceitaDao: receitaId
    ReceitaDao-->>Cadastro: receitaId
    
    Cadastro->>IngredienteDao: insert(ingrediente)
    IngredienteDao->>DBProvider: database
    DBProvider->>SQLite: INSERT INTO ingrediente VALUES(...)
    SQLite-->>DBProvider: Success
    DBProvider-->>IngredienteDao: Success
    IngredienteDao-->>Cadastro: Success
    
    Cadastro->>PassoPreparoDao: insert(passo)
    PassoPreparoDao->>DBProvider: database
    DBProvider->>SQLite: INSERT INTO passo_preparo VALUES(...)
    SQLite-->>DBProvider: Success
    DBProvider-->>PassoPreparoDao: Success
    PassoPreparoDao-->>Cadastro: Success
    
    Cadastro-->>Usuario: Receita salva com sucesso!
    Cadastro->>Cadastro: Limpa rascunho
```

---

## 🔄 4. Diagrama de Sequência - Fluxo de Visualização de Receita

```mermaid
sequenceDiagram
    actor Usuario
    participant LivroDeReceitas
    participant CategoriaPage
    participant RecipeDetailsPage
    participant ReceitaDao
    participant IngredienteDao
    participant PassoPreparoDao
    participant DBProvider
    participant SQLite

    Usuario->>LivroDeReceitas: Acessa tela inicial
    LivroDeReceitas->>ReceitaDao: getAll()
    ReceitaDao->>DBProvider: database
    DBProvider->>SQLite: SELECT * FROM receita
    SQLite-->>DBProvider: Receitas
    DBProvider-->>ReceitaDao: Receitas
    ReceitaDao-->>LivroDeReceitas: Receitas
    LivroDeReceitas-->>Usuario: Exibe receitas por categoria

    Usuario->>CategoriaPage: Clica em categoria
    CategoriaPage->>ReceitaDao: getAll()
    ReceitaDao->>DBProvider: database
    DBProvider->>SQLite: SELECT * FROM receita WHERE categoria_id = ?
    SQLite-->>DBProvider: Receitas da categoria
    DBProvider-->>ReceitaDao: Receitas da categoria
    ReceitaDao-->>CategoriaPage: Receitas da categoria
    CategoriaPage-->>Usuario: Exibe lista filtrada

    Usuario->>RecipeDetailsPage: Clica em receita
    
    RecipeDetailsPage->>ReceitaDao: getById(recipeId)
    ReceitaDao->>DBProvider: database
    DBProvider->>SQLite: SELECT * FROM receita WHERE id = ?
    SQLite-->>DBProvider: Receita
    DBProvider-->>ReceitaDao: Receita
    ReceitaDao-->>RecipeDetailsPage: Receita

    RecipeDetailsPage->>IngredienteDao: getAllByReceita(recipeId)
    IngredienteDao->>DBProvider: database
    DBProvider->>SQLite: SELECT * FROM ingrediente WHERE receita_id = ?
    SQLite-->>DBProvider: Ingredientes
    DBProvider-->>IngredienteDao: Ingredientes
    IngredienteDao-->>RecipeDetailsPage: Ingredientes

    RecipeDetailsPage->>PassoPreparoDao: getAllByReceita(recipeId)
    PassoPreparoDao->>DBProvider: database
    DBProvider->>SQLite: SELECT * FROM passo_preparo WHERE receita_id = ?
    SQLite-->>DBProvider: Passos
    DBProvider-->>PassoPreparoDao: Passos
    PassoPreparoDao-->>RecipeDetailsPage: Passos

    RecipeDetailsPage-->>Usuario: Exibe receita completa com ingredientes e passos
```

---

## 📝 5. Diagrama de Entidade-Relacionamento (ER) - Banco de Dados

```mermaid
erDiagram
    CATEGORIA {
        int id PK
        string nome UK
    }

    RECEITA {
        int id PK
        string titulo
        string descricao
        int tempo_preparo
        int porcoes
        int dificuldade
        string data_cadastro
        int categoria_id FK
        string imagem
    }

    INGREDIENTE {
        int id PK
        string nome
        real quantidade
        string unidade_medida
        int receita_id FK
    }

    PASSO_PREPARO {
        int id PK
        int ordem
        string descricao
        int receita_id FK
        boolean feito
    }

    CATEGORIA ||--o{ RECEITA : "contém"
    RECEITA ||--o{ INGREDIENTE : "possui"
    RECEITA ||--o{ PASSO_PREPARO : "inclui"
```

---

## 🏗️ 6. Diagrama de Arquitetura em Camadas

```mermaid
graph TB
    subgraph Presentation["📱 Camada de Apresentação (UI)"]
        MainApp["MainApp"]
        LivroDeReceitas["LivroDeReceitas\n(Tela Principal)"]
        CategoriaPage["CategoriaPage\n(Filtro por Categoria)"]
        RecipeDetailsPage["RecipeDetailsPage\n(Detalhes da Receita)"]
        Cadastro["Cadastro\n(Formulário)"]
    end

    subgraph Models["📦 Camada de Modelos (Domain)"]
        Receita["Receita"]
        Categoria["Categoria"]
        Ingrediente["Ingrediente"]
        PassoPreparo["PassoPreparo"]
    end

    subgraph Data["💾 Camada de Persistência (Data)"]
        DAO["DAOs<br/>(ReceitaDao, CategoriaDao,<br/>IngredienteDao, PassoPreparoDao)"]
        DBProvider["DBProvider<br/>(Gerenciador de BD)"]
    end

    subgraph Database["🗄️ Banco de Dados"]
        SQLite["SQLite<br/>(receitas.db)"]
    end

    MainApp --> LivroDeReceitas
    MainApp --> Cadastro
    LivroDeReceitas --> CategoriaPage
    CategoriaPage --> RecipeDetailsPage
    CategoriaPage --> Cadastro

    Presentation --> Models
    LivroDeReceitas --> DAO
    CategoriaPage --> DAO
    RecipeDetailsPage --> DAO
    Cadastro --> DAO

    DAO --> DBProvider
    Models -.->|Serialização| DAO
    DBProvider --> SQLite

    style Presentation fill:#e1f5ff
    style Models fill:#f3e5f5
    style Data fill:#e8f5e9
    style Database fill:#fff3e0
```

---

## 📊 7. Diagrama de Estados - Ciclo de Vida de uma Receita

```mermaid
stateDiagram-v2
    direction TB
    [*] --> Criando
    
    Criando --> Salvando: Usuário clica 'Salvar'
    Salvando --> Salva: Receita gravada no BD
    Salva --> Visualizando: Usuário acessa receita
    
    Visualizando --> Editando: Usuário clica 'Editar'
    Editando --> Atualizando: Usuário clica 'Atualizar'
    Atualizando --> Salva: Receita atualizada no BD
    
    Visualizando --> Usando: Usuário consulta durante preparo
    Usando --> Visualizando: Usuário volta para detalhes
    
    Salva --> Removendo: Usuário clica 'Deletar'
    Removendo --> Removida: Receita deletada do BD
    Removida --> [*]
    
    note right of Criando
        Preenchimento do 
        formulário de cadastro
    end note
    
    note right of Salvando
        Validação de dados
        Inserção no BD
    end note
    
    note right of Visualizando
        Carregamento de 
        ingredientes e passos
    end note
    
    note right of Usando
        Marca ingredientes/passos
        Assistente de voz ativo
    end note

    note right of Removendo
        Exclusão da receita
        e limpeza dos dados
    end note
```
```


---

## 🔑 Componentes-Chave

### Padrões de Design Utilizados:

1. **Singleton Pattern**: `DBProvider` (garante única instância do BD)
2. **DAO Pattern**: `ReceitaDao`, `CategoriaDao`, etc. (abstrai acesso ao BD)
3. **Model Pattern**: Classes de modelo com `toMap()` e `fromMap()` (serialização)
4. **Stateful Widget Pattern**: Páginas que gerenciam estado local (Flutter)

### Fluxo Principal de Dados:

```
Usuário Input → Widget (UI) → DAO Layer → DBProvider → SQLite Database
SQLite Database → DBProvider → DAO Layer → Model Objects → Widget (UI) → Usuário
```

### Dependências Críticas:

- 🔴 **Receita** depende de **Categoria** (categoria_id)
- 🔴 **Ingrediente** depende de **Receita** (receita_id)
- 🔴 **PassoPreparo** depende de **Receita** (receita_id)

---

## 📱 Principais Funcionalidades

| Funcionalidade | Componentes | Fluxo |
|---|---|---|
| **Listar Receitas** | LivroDeReceitas → ReceitaDao | getAll() → Exibição por categoria |
| **Filtrar por Categoria** | CategoriaPage → ReceitaDao | WHERE categoria_id → getAll() filtrado |
| **Visualizar Detalhes** | RecipeDetailsPage → Todos DAOs | getById() + getAllByReceita() |
| **Cadastrar** | Cadastro → ReceitaDao + IngredienteDao + PassoPreparoDao | insert() transacional |
| **Editar** | Cadastro → ReceitaDao.update() | UPDATE receita |
| **Deletar** | RecipeDetailsPage → ReceitaDao.delete() | DELETE + cascata de FK |
| **Assistente de Voz** | RecipeDetailsPage → SpeechToText + FlutterTts | Marca items + Feedback auditivo |
| **Rascunho Auto** | Cadastro → File I/O | JSON local storage |

