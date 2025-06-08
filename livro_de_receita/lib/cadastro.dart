import 'package:flutter/material.dart';
import 'appbar.dart';
import 'package:livro_de_receita/Infra/models/receita.dart';
import 'package:livro_de_receita/Infra/models/ingrediente.dart';
import 'package:livro_de_receita/Infra/models/passo_preparo.dart';
import 'package:livro_de_receita/Infra/models/categoria.dart';
import 'package:livro_de_receita/Infra/data/dao/receita_dao.dart';
import 'package:livro_de_receita/Infra/data/dao/ingrediente_dao.dart';
import 'package:livro_de_receita/Infra/data/dao/passo_preparo_dao.dart';
import 'package:livro_de_receita/Infra/data/dao/categoria_dao.dart';

class Cadastro extends StatefulWidget {
  const Cadastro({super.key});
  
  @override
  State<Cadastro> createState() => _CadastroState();
}

// Estado da tela de cadastro
class _CadastroState extends State<Cadastro> {
  // Chave para validação do formulário
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  int? _categoriaId;
  String? _imagemAsset;
  final List<Ingrediente> _ingredientes = [];
  final List<PassoPreparo> _passos = [];
  List<Categoria> _categorias = [];
  final List<Map<String, String>> _imagensDisponiveis = [
    {'path': 'assets/images/receita_default.png', 'nome': 'Padrão'},
    {'path': 'assets/images/lanche.png', 'nome': 'Lanche'},
    {'path': 'assets/images/salgadinho.png', 'nome': 'Salgadinho'},
    {'path': 'assets/images/torta_salgada.png', 'nome': 'Torta Salgada'},
    {'path': 'assets/images/cachorro_quente.png', 'nome': 'Cachorro Quente'},
    {'path': 'assets/images/prato_de_comida.png', 'nome': 'Prato de Comida'},
    {'path': 'assets/images/salada.png', 'nome': 'Salada'},
    {'path': 'assets/images/bolo.png', 'nome': 'Bolo'},
    {'path': 'assets/images/docinhos.png', 'nome': 'Docinhos'},
    {'path': 'assets/images/torta_doce.png', 'nome': 'Torta Doce'},
    {'path': 'assets/images/mousse.png', 'nome': 'Mousse'},
    {'path': 'assets/images/drinks.png', 'nome': 'Drinks'},
    {'path': 'assets/images/sucos.png', 'nome': 'Sucos'},
  ];
  
  @override
  void initState() {
    super.initState();
    // Carrega categorias após o build inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarCategorias();
    });
  }

  @override
  void dispose() {
    // Libera recursos do controlador
    _nomeController.dispose();
    super.dispose();
  }
  // Carrega todas as categorias disponíveis do banco de dados
  Future<void> _carregarCategorias() async {
    try {
      final categorias = await CategoriaDao.getAll();
      
      // Atualiza interface se a tela ainda estiver ativa
      if (mounted) {
        setState(() {
          _categorias = categorias;
          if (_categoriaId == null && _categorias.isNotEmpty) {
            _categoriaId = _categorias.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar categorias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removerImagem() {
    setState(() {
      _imagemAsset = null;
    });
  }

  void _selecionarImagemPreDefinida() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Selecionar Imagem da Receita',
              style: TextStyle(color: Colors.black),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: _imagensDisponiveis.length,
                itemBuilder: (context, index) {
                  final imagem = _imagensDisponiveis[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _imagemAsset = imagem['path'];
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              _imagemAsset == imagem['path']
                                  ? Colors.red.shade600
                                  : Colors.red.shade200,
                          width: _imagemAsset == imagem['path'] ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: Image.asset(
                                imagem['path']!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.restaurant,
                                      size: 40,
                                      color: Colors.red.shade600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              imagem['nome']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    _imagemAsset == imagem['path']
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
    );
  }

  void _adicionarIngrediente(String nome, double quantidade, String unidade) {
    setState(() {
      _ingredientes.add(
        Ingrediente(
          nome: nome,
          quantidade: quantidade,
          unidadeMedida: unidade,
          receitaId: 0,
        ),
      );
    });
  }

  void _removerIngrediente(int index) {
    setState(() {
      _ingredientes.removeAt(index);
    });
  }

  void _adicionarPasso(String descricao) {
    setState(() {
      _passos.add(
        PassoPreparo(
          ordem: _passos.length + 1,
          descricao: descricao,
          receitaId: 0,
          feito: false,
        ),
      );
    });
  }

  void _removerPasso(int index) {
    setState(() {
      _passos.removeAt(index);
      for (int i = 0; i < _passos.length; i++) {
        _passos[i] = PassoPreparo(
          ordem: i + 1,
          descricao: _passos[i].descricao,
          receitaId: _passos[i].receitaId,
          feito: _passos[i].feito,
        );
      }
    });
  }

  Future<void> _salvarReceita() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Adicione pelo menos um ingrediente'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    if (_passos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Adicione pelo menos um passo de preparo'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    _formKey.currentState!.save();
    final nome = _nomeController.text.trim();
    try {
      final receita = Receita(
        titulo: nome,
        descricao: 'Receita de ${nome.toLowerCase()}',
        tempoPreparo: 0,
        porcoes: 0,
        dificuldade: 0,
        dataCadastro: DateTime.now(),
        categoriaId: _categoriaId!,
        imagem: _imagemAsset,
      );
      final receitaId = await ReceitaDao.insert(receita);
      for (var ingrediente in _ingredientes) {
        final ingredienteComId = ingrediente.copyWith(receitaId: receitaId);
        await IngredienteDao.insert(ingredienteComId);
      }
      for (var passo in _passos) {
        final passoComId = passo.copyWith(receitaId: receitaId);
        await PassoPreparoDao.insert(passoComId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Receita salva com sucesso!'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar receita: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarCustomizado(
        titulo: "Cadastro",
        mostrarIconeAdicionar: false,
      ),
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DropdownButtonFormField<int>(
                  value: _categoriaId,
                  items:
                      _categorias
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nome),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _categoriaId = v),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    hintText: 'Selecione uma categoria',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator:
                      (v) => v == null ? 'Selecione uma categoria' : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  hintText: 'Digite o nome da receita',
                  prefixIcon: const Icon(Icons.restaurant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator:
                    (v) => v?.isEmpty == true ? 'Nome é obrigatório' : null,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Imagem da Receita',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        if (_imagemAsset != null)
                          IconButton(
                            onPressed: _removerImagem,
                            icon: const Icon(Icons.delete),
                            color: Colors.red.shade600,
                            tooltip: 'Remover imagem',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_imagemAsset != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.red.shade600,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            _imagemAsset!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.restaurant,
                                    size: 80,
                                    color: Colors.red.shade600,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _imagensDisponiveis.firstWhere(
                                      (img) => img['path'] == _imagemAsset,
                                      orElse:
                                          () => {'nome': 'Imagem Selecionada'},
                                    )['nome']!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 48,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhuma imagem selecionada',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selecionarImagemPreDefinida,
                        icon: const Icon(Icons.collections),
                        label: const Text('Selecionar Imagem'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredientes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_ingredientes.isEmpty)
                      Text(
                        'Nenhum ingrediente adicionado',
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      ..._ingredientes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final ingrediente = entry.value;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '• ${ingrediente.nome} (${ingrediente.quantidade} ${ingrediente.unidadeMedida})',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removerIngrediente(index),
                                icon: const Icon(Icons.delete),
                                color: Colors.red.shade600,
                                iconSize: 20,
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final nomeController = TextEditingController();
                        final quantidadeController = TextEditingController();
                        final unidadeController = TextEditingController();
                        await showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Text(
                                  'Adicionar Ingrediente',
                                  style: TextStyle(color: Colors.black),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nomeController,
                                      decoration: InputDecoration(
                                        labelText: 'Nome do ingrediente',
                                        labelStyle: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: quantidadeController,
                                      decoration: InputDecoration(
                                        labelText: 'Quantidade',
                                        labelStyle: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: unidadeController,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Unidade (ex: kg, ml, xícaras)',
                                        labelStyle: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      if (nomeController.text.isNotEmpty) {
                                        _adicionarIngrediente(
                                          nomeController.text,
                                          double.tryParse(
                                                quantidadeController.text,
                                              ) ??
                                              0,
                                          unidadeController.text,
                                        );
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: Text(
                                      'Adicionar',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar Ingrediente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo de Preparo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_passos.isEmpty)
                      Text(
                        'Nenhum passo adicionado',
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      ..._passos.asMap().entries.map((entry) {
                        final index = entry.key;
                        final passo = entry.value;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${passo.ordem}. ${passo.descricao}',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removerPasso(index),
                                icon: const Icon(Icons.delete),
                                color: Colors.red.shade600,
                                iconSize: 20,
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final passoController = TextEditingController();
                        await showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Text(
                                  'Adicionar Passo',
                                  style: TextStyle(color: Colors.black),
                                ),
                                content: TextField(
                                  controller: passoController,
                                  decoration: InputDecoration(
                                    labelText: 'Descrição do passo',
                                    labelStyle: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.red.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                  ),
                                  maxLines: 3,
                                  style: const TextStyle(color: Colors.black),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      if (passoController.text.isNotEmpty) {
                                        _adicionarPasso(passoController.text);
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: Text(
                                      'Adicionar',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar Passo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _salvarReceita,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Salvar Receita',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
