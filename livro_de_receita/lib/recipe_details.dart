import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _speechAvailable = false;
  bool _assistantActive = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _assistantMode = 'ingredientes';
  int _currentIngredientIndex = 0;
  int _currentStepIndex = 0;
  String _lastAssistantMessage = '';
  bool _hasChanges = false;
  bool _allowPop = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _titulo = widget.title;
    _imageUrl = widget.imageUrl;
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initVoiceAssistant();
    // Carrega os detalhes da receita ao inicializar
    _loadRecipeDetails();
  }

  Future<void> _initVoiceAssistant() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() {
            _isListening = false;
          });
          if (_assistantActive && !_isSpeaking) {
            _startListening();
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
      },
    );
    await _tts.awaitSpeakCompletion(true);
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

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  String _extractIngredientName(String ingrediente) {
    final lower = ingrediente.toLowerCase();
    final idx = lower.lastIndexOf(' de ');
    if (idx != -1 && idx + 4 < ingrediente.length) {
      return ingrediente.substring(idx + 4).trim();
    }
    return ingrediente.trim();
  }

  String? _extractRequestedName(String normalizedText) {
    final match = RegExp(r'(ingrediente|item)\s+(.+)$').firstMatch(
      normalizedText,
    );
    if (match == null) return null;
    var name = match.group(2) ?? '';
    name = name.replaceAll(RegExp(r'\bpor favor\b'), '').trim();
    return name.isEmpty ? null : name;
  }

  int? _parseIndexToken(String token) {
    final parsed = int.tryParse(token);
    if (parsed != null) return parsed - 1;
    const ordinals = {
      'primeiro': 0,
      'primeira': 0,
      'segundo': 1,
      'segunda': 1,
      'terceiro': 2,
      'terceira': 2,
      'quarto': 3,
      'quarta': 3,
      'quinto': 4,
      'quinta': 4,
      'sexto': 5,
      'sexta': 5,
      'setimo': 6,
      'setima': 6,
      'oitavo': 7,
      'oitava': 7,
      'nono': 8,
      'nona': 8,
      'decimo': 9,
      'decima': 9,
    };
    const cardinals = {
      'um': 0,
      'uma': 0,
      'dois': 1,
      'duas': 1,
      'tres': 2,
      'quatro': 3,
      'cinco': 4,
      'seis': 5,
      'sete': 6,
      'oito': 7,
      'nove': 8,
      'dez': 9,
    };
    return ordinals[token] ?? cardinals[token];
  }

  int? _findIndexByKeyword(String normalizedText, String keyword, int max) {
    if (max <= 0) return null;
    final digitAfter = RegExp('$keyword\\s*(\\d+)').firstMatch(normalizedText);
    if (digitAfter != null) {
      final idx = _parseIndexToken(digitAfter.group(1) ?? '');
      if (idx != null && idx >= 0 && idx < max) return idx;
    }
    final digitBefore = RegExp('(\\d+)\\s+$keyword').firstMatch(normalizedText);
    if (digitBefore != null) {
      final idx = _parseIndexToken(digitBefore.group(1) ?? '');
      if (idx != null && idx >= 0 && idx < max) return idx;
    }
    final wordAfter = RegExp('$keyword\\s+([a-z]+)').firstMatch(normalizedText);
    if (wordAfter != null) {
      final idx = _parseIndexToken(wordAfter.group(1) ?? '');
      if (idx != null && idx >= 0 && idx < max) return idx;
    }
    final wordBefore = RegExp('([a-z]+)\\s+$keyword').firstMatch(normalizedText);
    if (wordBefore != null) {
      final idx = _parseIndexToken(wordBefore.group(1) ?? '');
      if (idx != null && idx >= 0 && idx < max) return idx;
    }
    return null;
  }

  int _ingredientMatchScore(String text, String ingredientName) {
    final words = ingredientName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    var score = 0;
    for (final word in words) {
      if (text.contains(word)) {
        score += 1;
      }
    }
    return score;
  }

  bool _allIngredientsChecked() {
    return _ingredientChecked.isNotEmpty &&
        _ingredientChecked.every((v) => v);
  }

  int _resolveIngredientIndexForMark() {
    if (_loadedIngredients.isEmpty) return -1;
    if (_currentIngredientIndex >= 0 &&
        _currentIngredientIndex < _loadedIngredients.length &&
        !_ingredientChecked[_currentIngredientIndex]) {
      return _currentIngredientIndex;
    }
    return _ingredientChecked.indexWhere((v) => !v);
  }

  int _resolveStepIndexForMark() {
    if (_loadedInstructions.isEmpty) return -1;
    if (_currentStepIndex >= 0 && _currentStepIndex < _loadedInstructions.length) {
      return _currentStepIndex;
    }
    return 0;
  }

  int _findNextUncheckedIngredient(int fromIndex) {
    if (_loadedIngredients.isEmpty) return -1;
    for (var i = fromIndex + 1; i < _ingredientChecked.length; i++) {
      if (!_ingredientChecked[i]) return i;
    }
    for (var i = 0; i <= fromIndex && i < _ingredientChecked.length; i++) {
      if (!_ingredientChecked[i]) return i;
    }
    return -1;
  }

  Future<void> _falarIngredienteAtual() async {
    final index = _resolveIngredientIndexForMark();
    if (index == -1) {
      await _speakAndResume('Nao ha ingredientes cadastrados.');
      return;
    }
    _currentIngredientIndex = index;
    await _speakAndResume('Ingrediente: ${_loadedIngredients[index]}.');
  }

  Future<void> _falarPassoAtual() async {
    final index = _resolveStepIndexForMark();
    if (index == -1) {
      await _speakAndResume('Nao ha passos de preparo cadastrados.');
      return;
    }
    _currentStepIndex = index;
    await _falarPasso(index);
  }

  Future<void> _irParaModoPreparo() async {
    _assistantMode = 'passos';
    if (_loadedInstructions.isNotEmpty) {
      _currentStepIndex = 0;
      await _speakAndResume(
        'Ingredientes finalizados. Vamos para o modo de preparo. '
        'Passo 1: ${_loadedInstructions.first}.',
      );
    } else {
      await _speakAndResume(
        'Ingredientes finalizados. Nao ha passos de preparo cadastrados.',
      );
    }
  }

  Future<void> _avancarIngrediente(int fromIndex) async {
    final nextIndex = _findNextUncheckedIngredient(fromIndex);
    if (nextIndex == -1) {
      await _irParaModoPreparo();
      return;
    }
    _currentIngredientIndex = nextIndex;
    await _speakAndResume('Proximo ingrediente: ${_loadedIngredients[nextIndex]}.');
  }

  Future<void> _avancarPasso(int fromIndex) async {
    final nextIndex = fromIndex + 1;
    if (nextIndex >= _loadedInstructions.length) {
      await _speakAndResume('Todos os passos finalizados.');
      return;
    }
    _currentStepIndex = nextIndex;
    await _falarPasso(nextIndex);
  }

  Future<void> _toggleAssistant() async {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aguarde o carregamento da receita'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reconhecimento de voz indisponível'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }
    if (_assistantActive) {
      await _stopAssistant();
    } else {
      await _startAssistant();
    }
  }

  Future<void> _startAssistant() async {
    setState(() {
      _assistantActive = true;
      _assistantMode = 'ingredientes';
      _currentStepIndex = 0;
    });
    final ingredientesTexto = _loadedIngredients.isEmpty
        ? 'Nenhum ingrediente informado.'
        : _loadedIngredients.join(', ');
    await _speakAndResume(
      'Vamos começar a receita $_titulo. Pegue os ingredientes: '
      '$ingredientesTexto. Quando pegar, diga "peguei".',
    );
  }

  Future<void> _stopAssistant() async {
    await _speech.stop();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _assistantActive = false;
      _isListening = false;
    });
  }

  Future<void> _startListening() async {
    if (!_assistantActive || _isListening || _isSpeaking) return;
    final ok = _speechAvailable;
    if (!ok) return;
    setState(() {
      _isListening = true;
    });
    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    final texto = result.recognizedWords.trim();
    if (texto.isEmpty) return;
    _processVoiceCommand(texto);
  }

  Future<void> _speak(String text) async {
    _lastAssistantMessage = text;
    _isSpeaking = true;
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
    await _tts.stop();
    await _tts.speak(text);
    _isSpeaking = false;
  }

  Future<void> _speakAndResume(String text) async {
    await _speak(text);
    if (_assistantActive) {
      await _startListening();
    }
  }

  Future<void> _falarIngredientes() async {
    final texto = _loadedIngredients.isEmpty
        ? 'Nao ha ingredientes cadastrados.'
        : 'Ingredientes: ${_loadedIngredients.join(', ')}.';
    await _speakAndResume(texto);
  }

  Future<void> _falarPasso(int index) async {
    if (index < 0 || index >= _loadedInstructions.length) return;
    final texto = 'Passo ${index + 1}: ${_loadedInstructions[index]}.';
    await _speakAndResume(texto);
  }

  Future<void> _falarModoPreparo() async {
    if (_loadedInstructions.isEmpty) {
      await _speakAndResume('Nao ha passos de preparo cadastrados.');
      return;
    }
    final texto = _loadedInstructions
        .asMap()
        .entries
        .map((e) => 'Passo ${e.key + 1}: ${e.value}')
        .join('. ');
    await _speakAndResume('Modo de preparo: $texto.');
  }

  int? _findIngredientIndex(
    String normalizedText, {
    String? requestedName,
  }) {
    final requested = requestedName?.trim();
    if (requested != null && requested.isNotEmpty) {
      for (var i = 0; i < _loadedIngredients.length; i++) {
        final nome = _extractIngredientName(_loadedIngredients[i]);
        final nomeNorm = _normalize(nome);
        if (nomeNorm.isNotEmpty &&
            (nomeNorm.contains(requested) || requested.contains(nomeNorm))) {
          return i;
        }
      }
    }

    final byIngredient = _findIndexByKeyword(
      normalizedText,
      'ingrediente',
      _loadedIngredients.length,
    );
    if (byIngredient != null) return byIngredient;
    final byItem = _findIndexByKeyword(
      normalizedText,
      'item',
      _loadedIngredients.length,
    );
    if (byItem != null) return byItem;

    final targetText =
        requested != null && requested.isNotEmpty ? requested : normalizedText;
    var bestScore = 0;
    int? bestIndex;
    for (var i = 0; i < _loadedIngredients.length; i++) {
      final nome = _extractIngredientName(_loadedIngredients[i]);
      final nomeNorm = _normalize(nome);
      if (nomeNorm.isEmpty) continue;
      final score = _ingredientMatchScore(targetText, nomeNorm);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestScore > 0 ? bestIndex : null;
  }

  int? _findStepIndex(String normalizedText) {
    final byPasso = _findIndexByKeyword(
      normalizedText,
      'passo',
      _loadedInstructions.length,
    );
    if (byPasso != null) return byPasso;
    for (var i = 0; i < _loadedInstructions.length; i++) {
      final passoNorm = _normalize(_loadedInstructions[i]);
      if (passoNorm.isNotEmpty && normalizedText.contains(passoNorm)) {
        return i;
      }
    }
    return null;
  }

  Future<void> _processVoiceCommand(String transcript) async {
    final normalized = _normalize(transcript);
    final requestedName = _extractRequestedName(normalized);
    final wantsRepeat = normalized.contains('repet');
    final mentionsIngredientes = normalized.contains('ingrediente');
    final mentionsPassos =
        normalized.contains('passo') || normalized.contains('preparo');
    final wantsNext =
        normalized.contains('proximo') || normalized.contains('avancar');
    final wantsPrev =
        normalized.contains('voltar') || normalized.contains('anterior');
    final wantsAll =
        normalized.contains('tudo') || normalized.contains('todos');
    final wantsUnmark = normalized.contains('desmarc') ||
        normalized.contains('ainda nao') ||
        normalized.contains('nao peguei') ||
        normalized.contains('nao fiz');
    final wantsMark = !wantsUnmark &&
      (normalized.contains('peguei') ||
        normalized.contains('feito') ||
        normalized.contains('conclui') ||
        normalized.contains('pronto') ||
        normalized.contains('marcar'));

    if (wantsRepeat) {
      if (_assistantMode == 'ingredientes') {
        await _falarIngredienteAtual();
        return;
      }
      if (_assistantMode == 'passos') {
        await _falarPassoAtual();
        return;
      }
    }

    if (wantsNext || wantsPrev) {
      _assistantMode = 'passos';
      if (_loadedInstructions.isEmpty) {
        await _speakAndResume('Nao ha passos de preparo cadastrados.');
        return;
      }
      if (wantsNext) {
        _currentStepIndex =
            (_currentStepIndex + 1).clamp(0, _loadedInstructions.length - 1);
      } else {
        _currentStepIndex =
            (_currentStepIndex - 1).clamp(0, _loadedInstructions.length - 1);
      }
      await _falarPasso(_currentStepIndex);
      return;
    }

    if (mentionsIngredientes || requestedName != null || _assistantMode == 'ingredientes') {
      if (wantsAll && wantsUnmark) {
        setState(() {
          for (var i = 0; i < _ingredientChecked.length; i++) {
            _ingredientChecked[i] = false;
          }
        });
        await _speakAndResume('Ingredientes desmarcados.');
        return;
      }

      if (wantsAll && !wantsMark && !wantsUnmark) {
        await _falarIngredientes();
        return;
      }

      if (wantsAll && (wantsMark || normalized.contains('peguei'))) {
        setState(() {
          for (var i = 0; i < _ingredientChecked.length; i++) {
            _ingredientChecked[i] = true;
          }
        });
        await _irParaModoPreparo();
        return;
      }

      final ingredientIndex = _findIngredientIndex(
        normalized,
        requestedName: requestedName,
      );
      if (ingredientIndex != null) {
        final shouldMark = !wantsUnmark;
        setState(() {
          _ingredientChecked[ingredientIndex] = shouldMark;
        });
        if (shouldMark) {
          _currentIngredientIndex = ingredientIndex;
          await _avancarIngrediente(ingredientIndex);
          return;
        }
        _currentIngredientIndex = ingredientIndex;
        await _speakAndResume('Ingrediente desmarcado.');
        await _falarIngredienteAtual();
        return;
      }

      if (wantsMark && !wantsAll) {
        final nextIndex = _resolveIngredientIndexForMark();
        if (nextIndex != -1) {
          setState(() {
            _ingredientChecked[nextIndex] = true;
          });
          _currentIngredientIndex = nextIndex;
          await _avancarIngrediente(nextIndex);
          return;
        }
      }

      if (wantsUnmark && !wantsAll) {
        final index = _resolveIngredientIndexForMark();
        if (index != -1) {
          setState(() {
            _ingredientChecked[index] = false;
          });
          _currentIngredientIndex = index;
          await _speakAndResume('Ingrediente desmarcado.');
          await _falarIngredienteAtual();
          return;
        }
      }
    }

    if (mentionsPassos || _assistantMode == 'passos') {
      if (wantsAll && wantsUnmark) {
        setState(() {
          for (var i = 0; i < _instructionChecked.length; i++) {
            _instructionChecked[i] = false;
          }
        });
        await _speakAndResume('Passos desmarcados.');
        return;
      }
      if (wantsAll && !wantsMark && !wantsUnmark) {
        await _falarModoPreparo();
        return;
      }
      if (wantsAll && wantsMark) {
        setState(() {
          for (var i = 0; i < _instructionChecked.length; i++) {
            _instructionChecked[i] = true;
          }
        });
        await _speakAndResume('Todos os passos marcados.');
        return;
      }

      final stepIndex = _findStepIndex(normalized);
      if (stepIndex != null) {
        _assistantMode = 'passos';
        _currentStepIndex = stepIndex;
        if (wantsMark || wantsUnmark) {
          setState(() {
            _instructionChecked[stepIndex] = !wantsUnmark;
          });
          if (wantsUnmark) {
            await _speakAndResume('Passo desmarcado.');
            await _falarPasso(stepIndex);
            return;
          }
          await _avancarPasso(stepIndex);
          return;
        }
        await _falarPasso(stepIndex);
        return;
      }

      if (wantsMark && !wantsAll) {
        final index = _resolveStepIndexForMark();
        if (index != -1) {
          setState(() {
            _instructionChecked[index] = true;
          });
          _currentStepIndex = index;
          await _avancarPasso(index);
          return;
        }
      }

      if (wantsUnmark && !wantsAll) {
        final index = _resolveStepIndexForMark();
        if (index != -1) {
          setState(() {
            _instructionChecked[index] = false;
          });
          _currentStepIndex = index;
          await _speakAndResume('Passo desmarcado.');
          await _falarPasso(index);
          return;
        }
      }
    }

    await _speakAndResume(
      'Nao entendi. Opcoes: Repetir. Marcar ingrediente ou passo. '
      'Desmarcar ingrediente ou passo.',
    );
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
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
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
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleAssistant,
          backgroundColor: Colors.red.shade600,
          child: Icon(
            _assistantActive
                ? (_isListening ? Icons.mic : Icons.mic_none)
                : Icons.restaurant_menu,
          ),
          tooltip:
              _assistantActive ? 'Assistente ativo' : 'Ativar assistente',
        ),
      ),
    );
  }
}
