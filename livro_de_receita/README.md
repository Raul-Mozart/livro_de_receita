# 📖 Livro de Receitas

Um aplicativo móvel desenvolvido em Flutter para organizar e gerenciar receitas culinárias, permitindo aos usuários cadastrar, visualizar e acompanhar o preparo de suas receitas favoritas.

## 🎯 Objetivo

O aplicativo foi desenvolvido com o objetivo de facilitar a organização de receitas culinárias, oferecendo uma interface intuitiva para:
- Cadastrar novas receitas com ingredientes e modo de preparo
- Organizar receitas por categorias (Salgados, Doces, Bebidas)
- Visualizar detalhes completos das receitas
- Acompanhar o progresso do preparo com checkboxes interativas
- Gerenciar uma biblioteca pessoal de receitas
- Cozinhar com um assistente de voz que entende fala livre sobre a receita
  (veja [docs/ASSISTENTE_DE_VOZ.md](docs/ASSISTENTE_DE_VOZ.md))

## 🛠️ Tecnologias Utilizadas

### Framework Principal
- **Flutter 3.7.0+** - Framework multiplataforma para desenvolvimento móvel

### Linguagem
- **Dart** - Linguagem de programação otimizada para UI

### Banco de Dados
- **Cloud Firestore** - Receitas na nuvem por usuário, com banco local no aparelho (funciona sem internet)
- **Firebase Auth** - Login por e-mail e senha
- **sqflite** - Só para copiar, uma vez, o banco SQLite das versões anteriores

### Dependências Principais
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.15.0     # Inicialização do Firebase
  firebase_auth: ^6.7.0      # Login por e-mail e senha
  cloud_firestore: ^6.10.0   # Banco de receitas (local + nuvem)
  sqflite: ^2.0.0+4          # Leitura do banco antigo na migração
  path_provider: ^2.0.11     # Acesso a diretórios do sistema
  path: ^1.8.2               # Manipulação de caminhos de arquivos

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0      # Análise de código
  flutter_launcher_icons: ^0.13.1  # Geração de ícones do app
  fake_cloud_firestore: ^4.3.0     # Firestore em memória nos testes
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
├── main.dart                        # Ponto de entrada da aplicação
├── firebase_options.dart            # Projeto Firebase (provisório: demo; `flutterfire configure`)
├── pages/                           # Telas
│   ├── login_page.dart              # Entrar, criar conta e recuperar senha
│   ├── cadastro_page.dart           # Cadastro e edição de receitas
│   ├── categoria_page.dart          # Listagem por categoria
│   └── recipe_details_page.dart     # Detalhes da receita e assistente de voz
├── widgets/                         # Componentes reutilizáveis
│   ├── auth_gate.dart               # Login ou tela inicial, conforme a sessão
│   ├── appbar_customizado.dart      # Barra superior (nova receita, conta e sair)
│   └── recipe_image_widget.dart     # Exibição de imagens
├── assistant/                       # Assistente de voz
│   ├── recipe_assistant_service.dart    # Decide entre modo local e IA do backend
│   ├── local_recipe_interpreter.dart    # Entende a fala no próprio aparelho
│   ├── recipe_language.dart             # Normalização da fala e dos ingredientes
│   └── recipe_assistant_models.dart     # Contexto e resultado da interpretação
├── data/                            # Acesso aos dados
│   ├── firebase_setup.dart          # Inicialização, banco local e emuladores
│   ├── auth_service.dart            # Login (Firebase Auth) e mensagens de erro
│   ├── receita_repository.dart      # Receitas no Firestore (users/{uid}/receitas)
│   └── migracao_sqlite.dart         # Cópia única do banco SQLite antigo
└── models/                          # Modelos de dados
    ├── categoria.dart               # Catálogo fixo: Salgados, Doces, Bebidas
    ├── receita.dart                 # Receita com ingredientes e passos dentro
    ├── ingrediente.dart
    └── passo_preparo.dart

assets/config/      # Configuração local do assistente (app.env, fora do git)
backend/            # Servidor do assistente (guarda a chave da IA)
docs/               # Documentação (banco, Firebase, diagramas, assistente, como rodar)
firebase/           # Regras do Firestore, emuladores e testes das regras
test/               # Testes (repositório, migração, login, tela inicial)
third_party/        # Cópia ajustada do plugin speech_to_text
```

### Documentação
- [Como rodar o projeto no celular](docs/INICIALIZAR_PROJETO.md)
- [Assistente de voz e backend](docs/ASSISTENTE_DE_VOZ.md)
- [Banco de dados](docs/DATABASE.md)
- [Firebase: projeto, emuladores e regras](docs/FIREBASE.md)
- [Diagramas](docs/DIAGRAMAS.md)

### Entidades Principais
Cada receita é um documento em `users/{uid}/receitas/{id}` no Firestore, com ingredientes e passos dentro.

#### 🏷️ Categoria (fixa no código)
- **id**: 1 Salgados, 2 Doces, 3 Bebidas
- **nome**: Nome da categoria

#### 📄 Receita
- **id**: Identificador do documento (texto gerado pelo Firestore)
- **titulo**: Nome da receita (até 200 caracteres)
- **descricao**: Descrição detalhada
- **tempoPreparo**: Tempo em minutos
- **porcoes**: Número de porções
- **dificuldade**: Nível de dificuldade (1-5)
- **dataCadastro**: Data de criação
- **categoriaId**: Referência à categoria
- **imagem**: Imagem do app ou caminho da foto no aparelho
- **ingredientes** / **passos**: Listas dentro da receita (até 200 cada)

#### 🥗 Ingrediente
- **nome**: Nome do ingrediente
- **quantidade**: Quantidade numérica
- **unidadeMedida**: Unidade (kg, g, ml, xícaras, etc.)

#### 📝 Passo de Preparo
- **ordem**: Ordem sequencial do passo
- **descricao**: Instrução detalhada
- **feito**: Status de conclusão (boolean)

## 💻 Lógica de Funcionamento

### Fluxo Principal da Aplicação

1. **Inicialização**
   ```dart
   main() → MyApp() → CategoriaPage()
   ```

2. **Login**
   - `AuthGate` mostra o login sem sessão; com sessão, conecta `ReceitaRepository.atual` ao usuário
   - No primeiro login do aparelho, copia as receitas do banco SQLite antigo para a conta

3. **Tela Principal (Categoria)**
   - Exibe grade de categorias com ícones
   - Carrega receitas via `ReceitaRepository.atual.getAll()`
   - Filtra por categoria selecionada
   - Permite navegação para cadastro e detalhes

4. **Cadastro de Receitas**
   - Formulário com validação
   - Seleção de categoria via dropdown
   - Upload de imagem da galeria pré-definida
   - Adição dinâmica de ingredientes e passos
   - Uma gravação com a receita inteira (no aparelho na hora, na nuvem quando houver internet)

5. **Visualização de Detalhes**
   - Uma leitura traz a receita com ingredientes e passos
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

4. **Suba os emuladores do Firebase** (enquanto não houver projeto real; ver [docs/FIREBASE.md](docs/FIREBASE.md))
   ```bash
   cd firebase && npm install && npm run emulators
   ```

5. **Execute o aplicativo**
   ```bash
   flutter run
   ```

### Testes
```bash
flutter test                 # repositório, migração, login e tela inicial
cd firebase && npm test      # regras do Firestore no emulador (JDK 21+)
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