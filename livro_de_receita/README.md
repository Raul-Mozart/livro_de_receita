# 📖 Livro de Receitas

Um aplicativo móvel desenvolvido em Flutter para organizar e gerenciar receitas culinárias, permitindo aos usuários cadastrar, visualizar e acompanhar o preparo de suas receitas favoritas.

## 🎯 Objetivo

O aplicativo foi desenvolvido com o objetivo de facilitar a organização de receitas culinárias, oferecendo uma interface intuitiva para:
- Cadastrar novas receitas com ingredientes e modo de preparo
- Organizar receitas por categorias (Salgados, Doces, Bebidas)
- Visualizar detalhes completos das receitas
- Acompanhar o progresso do preparo com checkboxes interativas
- Gerenciar uma biblioteca pessoal de receitas

## 🛠️ Tecnologias Utilizadas

### Framework Principal
- **Flutter 3.7.0+** - Framework multiplataforma para desenvolvimento móvel

### Linguagem
- **Dart** - Linguagem de programação otimizada para UI

### Banco de Dados
- **SQLite** - Banco de dados local para persistência de dados
- **sqflite ^2.0.0+4** - Plugin Flutter para operações SQLite

### Dependências Principais
```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.0.0+4          # Banco de dados SQLite
  path_provider: ^2.0.11     # Acesso a diretórios do sistema
  path: ^1.8.2               # Manipulação de caminhos de arquivos

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0      # Análise de código
  flutter_launcher_icons: ^0.13.1  # Geração de ícones do app
```

### Plataformas Suportadas
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🏗️ Arquitetura do Projeto

### Estrutura de Diretórios
```
lib/
├── main.dart                    # Ponto de entrada da aplicação
├── appbar.dart                  # Widget personalizado da barra superior
├── cadastro.dart                # Tela de cadastro de receitas
├── categoria_page.dart          # Tela de listagem por categoria
├── recipe_details.dart          # Tela de detalhes da receita
├── recipe_image_widget.dart     # Widget para exibição de imagens
└── Infra/                       # Camada de infraestrutura
    ├── data/
    │   ├── db_provider.dart     # Provedor do banco de dados
    │   └── dao/                 # Data Access Objects
    │       ├── categoria_dao.dart
    │       ├── receita_dao.dart
    │       ├── ingrediente_dao.dart
    │       └── passo_preparo_dao.dart
    └── models/                  # Modelos de dados
        ├── categoria.dart
        ├── receita.dart
        ├── ingrediente.dart
        ├── passo_preparo.dart
        └── foto.dart
```

### Entidades Principais

#### 🏷️ Categoria
- **id**: Identificador único
- **nome**: Nome da categoria (Salgados, Doces, Bebidas)

#### 📄 Receita
- **id**: Identificador único
- **titulo**: Nome da receita
- **descricao**: Descrição detalhada
- **tempo_preparo**: Tempo em minutos
- **porcoes**: Número de porções
- **dificuldade**: Nível de dificuldade (1-5)
- **data_cadastro**: Data de criação
- **categoria_id**: Referência à categoria
- **imagem**: Caminho da imagem

#### 🥗 Ingrediente
- **id**: Identificador único
- **nome**: Nome do ingrediente
- **quantidade**: Quantidade numérica
- **unidade_medida**: Unidade (kg, g, ml, xícaras, etc.)
- **receita_id**: Referência à receita

#### 📝 Passo de Preparo
- **id**: Identificador único
- **ordem**: Ordem sequencial do passo
- **descricao**: Instrução detalhada
- **receita_id**: Referência à receita
- **feito**: Status de conclusão (boolean)

## 💻 Lógica de Funcionamento

### Fluxo Principal da Aplicação

1. **Inicialização**
   ```dart
   main() → MyApp() → CategoriaPage()
   ```

2. **Tela Principal (Categoria)**
   - Exibe grade de categorias com ícones
   - Carrega receitas do banco via `ReceitaDao.getAll()`
   - Filtra por categoria selecionada
   - Permite navegação para cadastro e detalhes

3. **Cadastro de Receitas**
   - Formulário com validação
   - Seleção de categoria via dropdown
   - Upload de imagem da galeria pré-definida
   - Adição dinâmica de ingredientes e passos
   - Persistência transacional no banco

4. **Visualização de Detalhes**
   - Carregamento lazy dos dados relacionados
   - Checkboxes interativas para acompanhamento
   - Opção de exclusão com confirmação
   - Exibição responsiva de imagens

## 🎨 Interface e Experiência do Usuário

### Design System
- **Material Design 3**: Componentes nativos do Flutter
- **Esquema de Cores**: Tons de vermelho (#D32F2F) como cor primária
- **Tipografia**: Roboto (padrão Material)
- **Iconografia**: Material Icons

### Componentes Personalizados
- **AppbarCustomizado**: Barra superior reutilizável
- **RecipeImageWidget**: Exibição de imagens com fallback
- **Formulários**: Validação em tempo real
- **GridView**: Layout responsivo para receitas

### Navegação
- **Navigator 2.0**: Navegação por pilha
- **MaterialPageRoute**: Transições animadas
- **Passagem de Parâmetros**: Entre telas via constructor

## 🚀 Como Executar

### Pré-requisitos
- Flutter SDK 3.7.0 ou superior
- Dart SDK
- Android Studio / VS Code
- Emulador Android/iOS ou dispositivo físico

### Instalação

1. **Clone o repositório**
   ```bash
   git clone [url-do-repositorio]
   cd livro_de_receitas
   ```

2. **Instale as dependências**
   ```bash
   flutter pub get
   ```

3. **Gere os ícones do app**
   ```bash
   dart run flutter_launcher_icons:main
   ```

4. **Execute o aplicativo**
   ```bash
   flutter run
   ```

### Build para Produção

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```