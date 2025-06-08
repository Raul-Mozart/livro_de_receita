import 'package:flutter/material.dart';
import 'cadastro.dart';
import 'recipe_details.dart';
import 'recipe_image_widget.dart';
import 'Infra/data/dao/receita_dao.dart';
import 'Infra/models/receita.dart';

class CategoriaPage extends StatefulWidget {
  final int categoriaId;
  final String titulo;
  final IconData icone;
  
  // Construtor da página de categoria
  const CategoriaPage({
    super.key,
    required this.categoriaId,
    required this.titulo,
    required this.icone,
  });
  
  @override
  State<CategoriaPage> createState() => _CategoriaPageState();
}

class _CategoriaPageState extends State<CategoriaPage> {
  List<Receita> _receitas = [];
  // Indica se está carregando dados do banco
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
      // Filtra apenas as receitas da categoria atual
      final receitasCategoria =
          receitas.where((r) => r.categoriaId == widget.categoriaId).toList();
      
      // Atualiza a interface com as receitas carregadas
      setState(() {
        _receitas = receitasCategoria;
        _isLoading = false;
      });
    } catch (e) {
      // Em caso de erro, para o carregamento
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
    // Verifica se a tela ainda está ativa antes de navegar
    if (!mounted) return;
    
    String imageUrl = recipe.imagem ?? 'assets/images/receita_default.png';
    
    // Cria a página de detalhes da receita
    final detailsPage = RecipeDetailsPage(
      title: recipe.titulo,
      imageUrl: imageUrl,
      ingredients: [], // Lista vazia - será carregada na tela de detalhes
      instructions: [], // Lista vazia - será carregada na tela de detalhes
      recipeId: recipe.id,
    );
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => detailsPage),
    );
    
    // Se a receita foi modificada/excluída, recarrega a lista
    if (result == true && mounted) {
      _carregarReceitas();
    }
  }
  // Constrói a interface visual da página
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.titulo,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Cadastro()),
              );
              // Se nova receita foi adicionada, recarrega a lista
              if (result == true) {
                _carregarReceitas();
              }
            },
          ),
        ],
      ),
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
              // Estado 2: Nenhuma receita encontrada
              : _receitas.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icone, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'Nenhuma receita de ${widget.titulo.toLowerCase()} cadastrada',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              )
              // Estado 3: Exibindo receitas em grid
              : RefreshIndicator(
                // Permite atualizar a lista puxando para baixo
                onRefresh: _carregarReceitas,
                // Grid com receitas
                child: GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 colunas
                    childAspectRatio: 0.85, // Proporção dos cards
                    crossAxisSpacing: 16, // Espaço horizontal entre cards
                    mainAxisSpacing: 16, // Espaço vertical entre cards
                  ),
                  // Número de itens no grid
                  itemCount: _receitas.length,
                  // Construtor de cada item do grid
                  itemBuilder: (context, index) {
                    final receita = _receitas[index];
                    return InkWell(
                      // Ação ao tocar no card
                      onTap:
                          () => _navegarParaDetalhesReceita(context, receita),
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Recorta conteúdo nas bordas
                        clipBehavior: Clip.antiAlias,
                        // Sombra do card
                        elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: RecipeImageWidget(
                                imagePath: receita.imagem,
                                width: double.infinity,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                fallbackIcon: widget.icone,
                                fallbackIconSize: 64,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                receita.titulo,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis, // Reticências se muito longo
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
