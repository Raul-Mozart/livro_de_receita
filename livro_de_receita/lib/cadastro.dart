import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
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
  Set<String> _unidadesSalvas = {}; // Histórico de unidades salvas
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
    // Carrega categorias e unidades após o build inicial
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _carregarCategorias();
      await _carregarUnidadesSalvas();
      await _recuperarRascunho(); // Traz de volta os passos/ingredientes digitados
      // Em dispositivos com pouca RAM (ex: Moto G), o OS mata o app enquanto a câmera tira foto.
      // Quando o app volta, nós recuperamos a foto tirada e a amarramos de volta.
      _recuperarDeLostData();
    });
  }

  // MÉTODOS DE BLINDAGEM DE DADOS (RASCUNHO)
  Future<void> _salvarRascunho() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rascunho_receita.json');
      final dados = {
        'nome': _nomeController.text,
        'categoriaId': _categoriaId,
        'ingredientes': _ingredientes.map((i) => {'nome': i.nome, 'quantidade': i.quantidade, 'unidadeMedida': i.unidadeMedida}).toList(),
        'passos': _passos.map((p) => {'ordem': p.ordem, 'descricao': p.descricao}).toList(),
      };
      await file.writeAsString(jsonEncode(dados));
    } catch (e) {}
  }

  Future<void> _recuperarRascunho() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rascunho_receita.json');
      if (await file.exists()) {
        final dados = jsonDecode(await file.readAsString());
        if (mounted) {
          setState(() {
            if (dados['nome'] != null && _nomeController.text.isEmpty) _nomeController.text = dados['nome'];
            if (dados['categoriaId'] != null) _categoriaId = dados['categoriaId'];
            if (dados['ingredientes'] != null && _ingredientes.isEmpty) {
              for (var i in dados['ingredientes']) {
                _ingredientes.add(Ingrediente(nome: i['nome'], quantidade: i['quantidade'], unidadeMedida: i['unidadeMedida'], receitaId: 0));
              }
            }
            if (dados['passos'] != null && _passos.isEmpty) {
              for (var p in dados['passos']) {
                _passos.add(PassoPreparo(ordem: p['ordem'], descricao: p['descricao'], receitaId: 0, feito: false));
              }
            }
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _apagarRascunho() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rascunho_receita.json');
      if (await file.exists()) await file.delete();
    } catch (e) {}
  }

  // Método nativo do package image_picker exclusivo para lidar com 
  // celulares Android que finalizam apps em background: 
  Future<void> _recuperarDeLostData() async {
    final picker = ImagePicker();
    final response = await picker.retrieveLostData();
    if (response.isEmpty) {
      return;
    }
    if (response.file != null && mounted) {
      setState(() {
        _imagemAsset = response.file!.path;
      });
      // Um pequeno aviso de que a foto foi recuperada após o sistema fechar a memória
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Foto recuperada com sucesso!'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    } 
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

  // Gerenciamento das Unidades de Medida
  Future<void> _carregarUnidadesSalvas() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/unidades_salvas.json');
      if (await file.exists()) {
        final List<dynamic> dados = jsonDecode(await file.readAsString());
        setState(() {
          _unidadesSalvas = dados.map((e) => e.toString()).toSet();
        });
      }
    } catch (e) {}
  }

  Future<void> _salvarUnidade(String unidade) async {
    final nomeLimpo = unidade.trim();
    if (nomeLimpo.isEmpty) return;
    try {
      setState(() {
        _unidadesSalvas.add(nomeLimpo);
      });
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/unidades_salvas.json');
      await file.writeAsString(jsonEncode(_unidadesSalvas.toList()));
    } catch (e) {}
  }

  Future<void> _excluirUnidadeSalva(String unidade) async {
    try {
      setState(() {
        _unidadesSalvas.remove(unidade);
      });
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/unidades_salvas.json');
      await file.writeAsString(jsonEncode(_unidadesSalvas.toList()));
    } catch (e) {}
  }

  void _removerImagem() {
    setState(() {
      _imagemAsset = null;
    });
  }

  Future<void> _tirarFoto() async {
    await _salvarRascunho(); // Salva o processo inteiro escrito até aqui
    try {
      final picker = ImagePicker();
      // Reduzindo as configurações de captura ao MÍNIMO estritamente essencial para impedir 
      // que o SO reinicie o app no Moto G50. Adicionado requestFullMetadata: false 
      // para pular o processamento pesado de EXIF que causa OOM no Android.
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Qualidade média/alta que não fica granulada
        maxWidth: 1200, // Tamanho grande o suficiente para não perder pixels na tela
        maxHeight: 1200,
        requestFullMetadata: false, // <-- A grande chave contra o travamento detalhado
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _imagemAsset = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao capturar foto: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _selecionarGaleria() async {
    await _salvarRascunho(); // Salva prevenção
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Tamanho amigável, qualidade média sem estourar nada
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _imagemAsset = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir a galeria: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
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
    if (descricao.trim().isEmpty) return;
    
    // Separa a descrição por quebras de linha para criar múltiplos passos de uma vez
    final linhas = descricao.split('\n');
    setState(() {
      for (var linha in linhas) {
        final txt = linha.trim();
        if (txt.isNotEmpty) {
          _passos.add(
            PassoPreparo(
              ordem: _passos.length + 1,
              descricao: txt,
              receitaId: 0,
              feito: false,
            ),
          );
        }
      }
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
      await _apagarRascunho(); // Limpa rascunho após salvar receita com sucesso
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
                        height: 250,
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
                          child: _imagemAsset!.startsWith('assets/')
                              ? Image.asset(
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
                                            orElse: () => {'nome': 'Imagem Selecionada'},
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
                                )
                              : Image.file(
                                  File(_imagemAsset!),
                                  fit: BoxFit.cover,
                                  cacheWidth: 800, // Ajuste para renderizar bem dimensionado
                                  filterQuality: FilterQuality.medium, // Melhora a granulação
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.restaurant,
                                        size: 80,
                                        color: Colors.red.shade600,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      )
                    else
                      Container(
                        height: 250,
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
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selecionarGaleria,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeria'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _tirarFoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Tirar Foto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
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
                                    StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: unidadeController,
                                              decoration: InputDecoration(
                                                labelText: 'Unidade (ex: kg, ml, xícaras)',
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
                                            if (_unidadesSalvas.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              const Text('Unidades recentes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: -8,
                                                children: _unidadesSalvas.map((u) => InputChip(
                                                  label: Text(u, style: const TextStyle(fontSize: 12)),
                                                  onPressed: () {
                                                    unidadeController.text = u;
                                                  },
                                                  onDeleted: () async {
                                                    await _excluirUnidadeSalva(u);
                                                    setDialogState(() {}); // Atualiza UI do Dialog
                                                  },
                                                  deleteIcon: const Icon(Icons.close, size: 14),
                                                )).toList(),
                                              ),
                                            ]
                                          ],
                                        );
                                      }
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
                                        _salvarUnidade(unidadeController.text);
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
