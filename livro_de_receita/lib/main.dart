import 'package:flutter/material.dart';
import 'appbar.dart';
import 'cadastro.dart';
import 'categoria_page.dart';
import 'recipe_details.dart';
import 'recipe_image_widget.dart';
import 'Infra/data/db_provider.dart';
import 'Infra/models/receita.dart';
import 'Infra/data/dao/receita_dao.dart';

void main() async {

  // Garante que o Flutter seja inicializado antes de usar plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o banco de dados antes de executar o app
  await DBProvider().database;

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LivroDeReceitas(),
        '/cadastro': (context) => const Cadastro(),
      },
      // Configuração do tema global do app
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey.shade50,
        // Tema da AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        // Tema dos botões elevados 
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
        ),
        // Tema dos campos de entrada
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red.shade600, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
        ),
        // Tema do botão flutuante
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

// Tela principal do livro de receitas (com estado)
class LivroDeReceitas extends StatefulWidget {
  const LivroDeReceitas({super.key});
  
  @override
  State<StatefulWidget> createState() => _LivroDeReceitas();
}

// Estado da tela principal
class _LivroDeReceitas extends State<LivroDeReceitas> {
  List<Receita> _salgados = [];
  List<Receita> _doces = [];
  List<Receita> _bebidas = [];

  // Indica se está carregando dados
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _carregarReceitas();
  }
  Future<void> _carregarReceitas() async {
    try {
      // Mostra indicador de carregamento
      setState(() {
        _isLoading = true;
      });
      
      final receitas = await ReceitaDao.getAll();
      
      setState(() {
        _salgados = receitas.where((r) => r.categoriaId == 1).toList();
        _doces = receitas.where((r) => r.categoriaId == 2).toList();
        _bebidas = receitas.where((r) => r.categoriaId == 3).toList();
        _isLoading = false;
      });
    } catch (e) {
      // Para carregamento em caso de erro
      setState(() {
        _isLoading = false;
      });
      
      // Exibe mensagem de erro se a tela ainda estiver ativa
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar receitas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  void _navegarParaDetalhesReceita(BuildContext context, Receita recipe) async {
    // Obtém referência do Navigator para uso seguro
    final navigator = Navigator.of(context);
    
    try {
      if (recipe.id == null) {
        throw Exception('ID da receita é nulo');
      }
      
      // Verifica se a tela ainda está ativa
      if (!mounted) return;
      
      // Define imagem da receita ou usa padrão
      String imageUrl = recipe.imagem ?? 'assets/images/receita_default.png';
      
      // Cria a página de detalhes
      final detailsPage = RecipeDetailsPage(
        title: recipe.titulo,
        imageUrl: imageUrl,
        ingredients: [], // Será carregado na tela de detalhes
        instructions: [], // Será carregado na tela de detalhes
        recipeId: recipe.id,
      );
      
      // Verifica novamente se a tela está ativa antes de navegar
      if (!mounted) return;
      
      final result = await navigator.push(
        MaterialPageRoute(builder: (context) => detailsPage),
      );
      
      // Verifica se ainda está ativa após navegação
      if (!mounted) return;
      
      // Se receita foi modificada/excluída, recarrega lista
      if (result == true) {
        _carregarReceitas();
      }
    } catch (e) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppbarCustomizado(),
      body:
          // Estado 1: Carregando dados
          _isLoading
              ? Center(
                // Indicador de carregamento circular
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.red.shade600,
                  ),
                ),
              )
              // Estado 2: Exibindo receitas por categoria
              : RefreshIndicator(
                // Permite atualizar puxando para baixo
                onRefresh: _carregarReceitas,
                // Scroll principal da tela
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seção de Doces
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CategoriaPage(
                                          categoriaId: 1,
                                          titulo: 'Salgados',
                                          icone: Icons.restaurant,
                                        ),
                                  ),
                                ),
                            child: _buildSectionTitle('Salgados'),
                          ),
                          // Botão "Ver Todos" para salgados
                          ElevatedButton.icon(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CategoriaPage(
                                          categoriaId: 1,
                                          titulo: 'Salgados',
                                          icone: Icons.restaurant,
                                        ),
                                  ),
                                ),
                            icon: Icon(Icons.restaurant, size: 18),
                            label: Text('Ver Todos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Cards de receitas salgadas
                      _buildRecipeCards(_salgados),
                      SizedBox(height: 24),
                      
                      // Seção de Doces
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CategoriaPage(
                                          categoriaId: 2,
                                          titulo: 'Doces',
                                          icone: Icons.cake,
                                        ),
                                  ),
                                ),
                            child: _buildSectionTitle('Doces'),
                          ),
                          // Botão "Ver Todos" para doces
                          ElevatedButton.icon(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CategoriaPage(
                                          categoriaId: 2,
                                          titulo: 'Doces',
                                          icone: Icons.cake,
                                        ),
                                  ),
                                ),
                            icon: Icon(Icons.cake, size: 18),
                            label: Text('Ver Todos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Cards de receitas doces
                      _buildRecipeCards(_doces),
                      SizedBox(height: 24),

                      // Seção de Bebidas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Título clicável da seção
                          InkWell(
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CategoriaPage(
                                          categoriaId: 3,
                                          titulo: 'Bebidas',
                                          icone: Icons.local_drink,
                                        ),
                                  ),
                                ),
                            child: _buildSectionTitle('Bebidas'),
                          ),
                          // Botão "Ver Todos" para bebidas
                          ElevatedButton.icon(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CategoriaPage(
                                          categoriaId: 3,
                                          titulo: 'Bebidas',
                                          icone: Icons.local_drink,
                                        ),
                                  ),
                                ),
                            icon: Icon(Icons.local_drink, size: 18),
                            label: Text('Ver Todos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Cards de bebidas
                      _buildRecipeCards(_bebidas),
                    ],
                  ),
                ),
              ),
    );
  }
  // Constrói o widget de título de seção estilizado
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // Constrói a lista horizontal de cards de receitas
  Widget _buildRecipeCards(List<Receita> recipes) {
    // Se não há receitas, exibe mensagem
    if (recipes.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            'Nenhuma receita cadastrada',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }
    
    // Lista horizontal de receitas
    return SizedBox(
      height: 260, // Altura fixa para scroll horizontal
      child: ListView.builder(
        scrollDirection: Axis.horizontal, // Scroll horizontal
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          // Container com margem para cada card
          return Container(
            margin: EdgeInsets.only(right: 16.0),
            // Card clicável
            child: InkWell(
              onTap: () => _navegarParaDetalhesReceita(context, recipe),
              borderRadius: BorderRadius.circular(12),
              // Tamanho fixo do card
              child: SizedBox(
                width: 220,
                // Coluna com imagem e título
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagem da receita com bordas arredondadas
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RecipeImageWidget(
                        imagePath: recipe.imagem,
                        width: double.infinity,
                        height: 180,
                        borderRadius: BorderRadius.circular(12),
                        fallbackIcon: _getIconForCategory(recipe),
                        fallbackIconSize: 64,
                      ),
                    ),
                    // Espaçamento
                    SizedBox(height: 8),
                    // Título da receita
                    Text(
                      recipe.titulo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2, // Máximo 2 linhas
                      overflow: TextOverflow.ellipsis, // Reticências se muito longo
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Retorna o ícone apropriado baseado na categoria da receita
  IconData _getIconForCategory(Receita recipe) {
    switch (recipe.categoriaId) {
      case 1: // Salgados
        return Icons.restaurant;
      case 2: // Doces
        return Icons.cake;
      case 3: // Bebidas
        return Icons.local_drink;
      default: // Padrão
        return Icons.restaurant;
    }
  }
}
