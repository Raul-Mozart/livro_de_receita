import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'cadastro.dart';
import 'Infra/data/dao/receita_dao.dart';
import 'Infra/data/dao/ingrediente_dao.dart';
import 'Infra/data/dao/passo_preparo_dao.dart';
import 'Infra/data/dao/categoria_dao.dart';

// Tela que exibe os detalhes completos de uma receita
class RecipeDetailsPage extends StatefulWidget {
  final String title;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> instructions;
  final int? recipeId;
  
  // Construtor da página
  const RecipeDetailsPage({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.ingredients,
    required this.instructions,
    this.recipeId,
  });
  
  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

// Estado da página de detalhes da receita
class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late List<bool> _ingredientChecked;
  late List<bool> _instructionChecked;
  List<String> _loadedIngredients = [];
  List<String> _loadedInstructions = [];
  late String _titulo;
  late String _imageUrl;
  String? _categoriaNome;
  bool _hasChanges = false;
  bool _allowPop = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _titulo = widget.title;
    _imageUrl = widget.imageUrl;
    // Carrega os detalhes da receita ao inicializar
    _loadRecipeDetails();
  }

  Future<void> _loadRecipeDetails() async {
    try {
      // Se tem ID da receita, carrega dados do banco
      if (widget.recipeId != null) {
        final receita = await ReceitaDao.getById(widget.recipeId!);
        if (receita != null) {
          _titulo = receita.titulo;
          _imageUrl = receita.imagem ?? 'assets/images/receita_default.png';
          final categoria = await CategoriaDao.getById(receita.categoriaId);
          _categoriaNome = categoria?.nome;
        }
        final ingredientes = await IngredienteDao.getAllByReceita(
          widget.recipeId!,
        );
        // Formata ingredientes como string (quantidade + unidade + nome)
        _loadedIngredients =
            ingredientes
                .map((i) => '${i.quantidade} ${i.unidadeMedida} de ${i.nome}')
                .toList();
        
        final passos = await PassoPreparoDao.getAllByReceita(widget.recipeId!);
        // Extrai apenas as descrições dos passos
        _loadedInstructions = passos.map((p) => p.descricao).toList();
      } else {
        // Se não tem ID, usa dados passados por parâmetro
        _loadedIngredients = widget.ingredients;
        _loadedInstructions = widget.instructions;
        _titulo = widget.title;
        _imageUrl = widget.imageUrl;
        _categoriaNome = null;
      }
      
      // Inicializa todas as checkboxes como desmarcadas
      _ingredientChecked = List.generate(
        _loadedIngredients.length,
        (_) => false,
      );
      _instructionChecked = List.generate(
        _loadedInstructions.length,
        (_) => false,
      );
      
      // Para o carregamento e atualiza a tela
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Em caso de erro, usa dados passados por parâmetro
      _loadedIngredients = widget.ingredients;
      _loadedInstructions = widget.instructions;
      _titulo = widget.title;
      _imageUrl = widget.imageUrl;
      _categoriaNome = null;
      
      // Inicializa checkboxes mesmo com erro
      _ingredientChecked = List.generate(
        _loadedIngredients.length,
        (_) => false,
      );
      _instructionChecked = List.generate(
        _loadedInstructions.length,
        (_) => false,
      );
      
      // Para o carregamento
      setState(() {
        _isLoading = false;
      });
    }
  }
  // Exibe diálogo de confirmação antes de excluir receita
  Future<void> _mostrarDialogoConfirmacao() async {
    if (widget.recipeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não é possível excluir: ID da receita não encontrado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Exibe diálogo de confirmação
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Não fecha ao tocar fora
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Exclusão'),
          // Conteúdo com mensagem de confirmação
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Tem certeza que deseja excluir a receita "${_titulo}"?',
                ),
                SizedBox(height: 8),
                // Aviso sobre irreversibilidade
                Text(
                  'Esta ação não pode ser desfeita.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Botões de ação
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // Botão para confirmar exclusão
            TextButton(
              child: Text('Excluir', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Fecha diálogo
                _excluirReceita();
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> _excluirReceita() async {
    try {
      if (widget.recipeId == null) {
        throw Exception('ID da receita não encontrado');
      }
      
      // Exibe indicador de carregamento durante exclusão
      showDialog(
        context: context,
        barrierDismissible: false, // Não pode ser fechado
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
        },
      );
      
      await ReceitaDao.delete(widget.recipeId!);
      
      // Verifica se a tela ainda está ativa
      if (!mounted) return;
      
      // Fecha o indicador de carregamento
      Navigator.of(context).pop();
      
      // Exibe mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receita excluída com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      
      _allowPop = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      // Verifica se a tela ainda está ativa
      if (!mounted) return;
      
      // Fecha indicador de carregamento se estiver aberto
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir receita: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ImageProvider _getImageProvider(String imageUrl) {
    try {
      if (imageUrl.isEmpty) {
        return const AssetImage('assets/images/receita_default.png');
      }
      // Se for asset, usa AssetImage
      if (imageUrl.startsWith('assets/')) {
        return AssetImage(imageUrl);
      } else {
        // Caso contrário, é uma foto local (câmera/galeria)
        return FileImage(File(imageUrl));
      }
    } catch (e) {
      // Em caso de erro, sempre usa imagem padrão
      return const AssetImage('assets/images/receita_default.png');
    }
  }

  String _buildRecipeShareText() {
    final buffer = StringBuffer();
    buffer.writeln('Receita: $_titulo');
    if (_categoriaNome != null && _categoriaNome!.isNotEmpty) {
      buffer.writeln('Categoria: $_categoriaNome');
    }
    buffer.writeln('');
    buffer.writeln('Ingredientes:');
    for (final ingrediente in _loadedIngredients) {
      buffer.writeln('- $ingrediente');
    }
    buffer.writeln('');
    buffer.writeln('Modo de Preparo:');
    for (var i = 0; i < _loadedInstructions.length; i++) {
      buffer.writeln('${i + 1}. ${_loadedInstructions[i]}');
    }
    return buffer.toString().trimRight();
  }

  Future<void> _copiarReceita() async {
    final texto = _buildRecipeShareText();
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receita copiada para a área de transferência'),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_allowPop) {
          return true;
        }
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          title: Text(_titulo),
          centerTitle: true,
          backgroundColor: Colors.red.shade600,
          actions: [
            IconButton(
              icon: Icon(Icons.copy),
              onPressed: _copiarReceita,
              tooltip: 'Copiar receita',
            ),
            if (widget.recipeId != null)
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => Cadastro(recipeId: widget.recipeId),
                    ),
                  );
                  if (result == true && mounted) {
                    setState(() {
                      _isLoading = true;
                      _hasChanges = true;
                    });
                    await _loadRecipeDetails();
                  }
                },
                tooltip: 'Editar receita',
              ),
            // Botão de exclusão
            if (widget.recipeId != null)
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: _mostrarDialogoConfirmacao,
                tooltip: 'Excluir receita',
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
                // Estado 2: Exibindo detalhes da receita
                : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 250,
                        color: Colors.grey[200],
                        child: Builder(
                          builder: (context) {
                            try {
                              return Image(
                                image: _getImageProvider(_imageUrl),
                                fit: BoxFit.cover,
                                // Widget de erro caso imagem não carregue
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.restaurant,
                                          size: 80,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Imagem não disponível",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            } catch (e) {
                              return Center(
                                child: Icon(
                                  Icons.restaurant,
                                  size: 80,
                                  color: Colors.grey[600],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ingredientes',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            ..._loadedIngredients.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _ingredientChecked[entry.key],
                                      onChanged: (value) {
                                        setState(() {
                                          _ingredientChecked[entry.key] =
                                              value ?? false;
                                        });
                                      },
                                      activeColor: Colors.red.shade600,
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontSize: 16,
                                          // Risca texto se marcado
                                          decoration:
                                              _ingredientChecked[entry.key]
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Modo de Preparo',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            ..._loadedInstructions.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Checkbox para marcar passo
                                    Checkbox(
                                      value: _instructionChecked[entry.key],
                                      onChanged: (value) {
                                        setState(() {
                                          _instructionChecked[entry.key] =
                                              value ?? false;
                                        });
                                      },
                                      activeColor: Colors.red.shade600,
                                    ),
                                    // Texto da instrução (expansível)
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontSize: 16,
                                          // Risca texto se marcado
                                          decoration:
                                              _instructionChecked[entry.key]
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
