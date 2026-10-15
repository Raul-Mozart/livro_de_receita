import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:livro_de_receita/pages/cadastro_page.dart';
import 'package:livro_de_receita/assistant/recipe_assistant_service.dart';
import 'package:livro_de_receita/data/receita_repository.dart';
import 'package:livro_de_receita/models/categoria.dart';

// Tela que exibe os detalhes completos de uma receita
class RecipeDetailsPage extends StatefulWidget {
  final String title;
  final String imageUrl;
  final List<String> ingredients;
  final List<String> instructions;
  final String? recipeId;

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
  bool _assistantMenuOpen = false;
  bool _assistantWasActive = false;
  String _assistantMode = 'ingredientes';
  int _currentIngredientIndex = 0;
  int _currentStepIndex = 0;
  String? _selectedLocaleId;
  final RecipeAssistantService _assistantService = RecipeAssistantService();
  bool _isProcessing = false;
  String _lastAssistantMessage = '';
  String? _pendingAssistantAction;
  final List<RecipeAssistantTurn> _assistantHistory = [];
  // Identifica a sessão do assistente e a fala mais recente, para descartar
  // respostas atrasadas de uma sessão anterior
  int _assistantSession = 0;
  int _speakToken = 0;
  int _speechErrorStreak = 0;
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

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == 'notListening' || status == 'done') {
      setState(() {
        _isListening = false;
      });
      if (_assistantActive && !_isSpeaking) {
        _restartListeningSoon(const Duration(milliseconds: 250));
      }
    }
  }

  // Reabre o microfone depois de uma pequena pausa (reabrir na hora faz o
  // Android responder "ocupado" e entrar em um ciclo de erros)
  void _restartListeningSoon(Duration delay) {
    final session = _assistantSession;
    Future.delayed(delay, () {
      if (mounted && _assistantActive && !_isSpeaking && session == _assistantSession) {
        _startListening();
      }
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
    if (!_assistantActive || _isSpeaking) return;
    final message = error.errorMsg;
    // Só desliga quando tentar de novo não resolve (sem permissão ou sem português)
    if (message == 'error_permission' ||
        message == 'error_language_not_supported' ||
        message == 'error_language_unavailable') {
      final session = _assistantSession;
      _speak(
        message == 'error_permission'
            ? 'Preciso de permissão para usar o microfone. Libere nas configurações do aparelho e toque no botão de novo.'
            : 'O reconhecimento de voz em português não está disponível neste aparelho.',
      ).then((_) {
        if (mounted && session == _assistantSession) _turnOffAssistant();
      });
      return;
    }
    // No Android todo erro vem marcado como "permanente", mas os comuns (sem fala,
    // ocupado, cliente, rede) só pedem uma nova tentativa, com pausa que cresce um pouco
    if (message == 'error_speech_timeout' || message == 'error_no_match') {
      _speechErrorStreak = 0;
    } else {
      _speechErrorStreak++;
    }
    _restartListeningSoon(Duration(milliseconds: 250 * (_speechErrorStreak.clamp(0, 8) + 1)));
  }

  // Desliga o assistente a partir da voz ou de um erro, como o botão faria
  Future<void> _turnOffAssistant() async {
    if (!mounted) return;
    setState(() {
      _assistantMenuOpen = false;
      _assistantWasActive = false;
    });
    await _stopAssistant();
  }

  // O SpeechToText é único no app: cada tela de receita precisa registrar
  // os próprios callbacks, senão eles continuam apontando para a tela anterior
  void _attachSpeechListeners() {
    _speech.statusListener = _onSpeechStatus;
    _speech.errorListener = _onSpeechError;
  }

  Future<void> _initVoiceAssistant() async {
    // O TTS é configurado primeiro: sem "aguardar fim da fala" o microfone
    // abriria enquanto o assistente ainda está falando
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('pt-BR');
    } catch (_) {
      // Mantém o idioma padrão do aparelho se pt-BR não estiver disponível.
    }

    _speechAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    _attachSpeechListeners();

    // O reconhecimento é sempre em português do Brasil, independente do idioma
    // configurado na digitação por voz do aparelho (a lista de idiomas do
    // aparelho às vezes nem responde e podia levar a um idioma errado)
    if (_speechAvailable) {
      _selectedLocaleId = 'pt-BR';
    }
  }

  Future<void> _loadRecipeDetails() async {
    try {
      // Se tem ID da receita, carrega dados do banco
      if (widget.recipeId != null) {
        // Uma leitura traz a receita com ingredientes e passos
        final receita = await ReceitaRepository.atual.getById(widget.recipeId!);
        if (receita != null) {
          _titulo = receita.titulo;
          _imageUrl = receita.imagem ?? 'assets/images/receita_default.png';
          _categoriaNome = Categoria.porId(receita.categoriaId)?.nome;
        }
        // Formata ingredientes como string (quantidade + unidade + nome)
        _loadedIngredients =
            (receita?.ingredientes ?? [])
                .map((i) => '${i.quantidade} ${i.unidadeMedida} de ${i.nome}')
                .toList();

        // Extrai apenas as descrições dos passos
        _loadedInstructions =
            (receita?.passos ?? []).map((p) => p.descricao).toList();
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
                Text('Tem certeza que deseja excluir a receita "$_titulo"?'),
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

  Future<void> _mostrarInfoAssistente() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Como usar o assistente'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Fale normalmente: o assistente entende o sentido da sua frase e responde com base nesta receita.',
                ),
                SizedBox(height: 8),
                Text('- "O que eu preciso pra fazer essa receita?"'),
                Text('- "Já peguei a farinha e os ovos."'),
                Text('- "Quanto de açúcar vai?"'),
                Text('- "Pronto, terminei. E agora?"'),
                Text('- "Em que passo eu uso o fermento?"'),
                Text('- "Quanto tempo fica no forno?"'),
                Text('- "Volta um passo." / "Repete, por favor."'),
                Text('- "Pode desligar o assistente."'),
                Text(
                  'Não precisa decorar comandos: pergunte do seu jeito, como falaria com alguém na cozinha.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fechar'),
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

      // Some do aparelho na hora; a nuvem recebe a exclusão quando houver conexão
      await ReceitaRepository.atual.delete(widget.recipeId!, imagem: _imageUrl);

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
      debugPrint('Falha ao excluir receita (${e.runtimeType})');
      // Verifica se a tela ainda está ativa
      if (!mounted) return;

      // Fecha indicador de carregamento se estiver aberto
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível excluir a receita. Tente de novo.'),
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
      setState(() {
        _assistantMenuOpen = false;
        _assistantWasActive = false;
      });
      await _stopAssistant();
      return;
    }

    setState(() {
      _assistantMenuOpen = false;
      _assistantWasActive = false;
    });
    await _startAssistant();
  }

  Future<void> _startAssistant() async {
    // Com passos já concluídos, retoma do primeiro passo pendente
    final hasProgress = _loadedInstructions.isNotEmpty && _instructionChecked.contains(true);
    final firstPendingStep = _instructionChecked.indexWhere((checked) => !checked);
    setState(() {
      _assistantActive = true;
      if (hasProgress) {
        _assistantMode = 'passos';
        _currentStepIndex = firstPendingStep == -1 ? _loadedInstructions.length - 1 : firstPendingStep;
      } else {
        _assistantMode = 'ingredientes';
        _currentStepIndex = 0;
      }
    });
    _assistantSession++;
    _isProcessing = false;
    _speechErrorStreak = 0;
    _attachSpeechListeners();
    _assistantHistory.clear();
    _lastAssistantMessage = '';
    final firstUnchecked = _ingredientChecked.indexWhere((checked) => !checked);
    _currentIngredientIndex = firstUnchecked == -1 ? 0 : firstUnchecked;
    String welcome;
    try {
      final context = _buildAssistantContext();
      _pendingAssistantAction = RecipeAssistantService.welcomePendingAction(context);
      welcome = RecipeAssistantService.welcomeMessage(context);
    } catch (_) {
      _pendingAssistantAction = null;
      welcome = 'Vamos começar a receita $_titulo. Pode falar comigo normalmente.';
    }
    _rememberTurn('assistant', welcome);
    // Prepara o interpretador enquanto a boas-vindas está sendo falada
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _assistantActive) {
        RecipeAssistantService.warmUp(_buildAssistantContext());
      }
    });
    await _speakAndResume(welcome);
  }

  Future<void> _stopAssistant() async {
    _assistantSession++;
    _isProcessing = false;
    _speakToken++; // interrompe uma fala em andamento
    _isSpeaking = false;
    // Marca como desligado antes de parar o microfone, para o aviso de
    // "parou de escutar" não reabrir a escuta
    _assistantActive = false;
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _tts.stop();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    // Não abre o microfone enquanto a fala anterior ainda está sendo interpretada
    if (!_assistantActive || _isListening || _isSpeaking || _isProcessing) return;
    if (!_speechAvailable) return;
    if (_speech.isListening) return;

    setState(() {
      _isListening = true;
    });

    try {
      await _speech.listen(
        localeId: _selectedLocaleId ?? 'pt-BR',
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 6),
        // Resultados parciais mantêm a escuta aberta enquanto a pessoa fala
        // (sem eles, frases longas eram cortadas); só o resultado final é usado
        listenOptions: stt.SpeechListenOptions(partialResults: true),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;
    _speechErrorStreak = 0;
    // O reconhecedor devolve a transcrição mais provável e outras alternativas;
    // todas são consideradas, porque a primeira às vezes vem com palavra trocada
    final transcricoes = <String>[];
    for (final texto in [
      result.recognizedWords,
      ...result.alternates.map((a) => a.recognizedWords),
    ]) {
      final limpo = texto.trim();
      if (limpo.isNotEmpty && !transcricoes.contains(limpo)) transcricoes.add(limpo);
    }
    if (transcricoes.isEmpty) {
      if (_assistantActive && !_isSpeaking && !_isListening) {
        _startListening();
      }
      return;
    }
    _processVoiceCommand(transcricoes);
  }

  // O TTS do Android não fala textos muito longos de uma vez (limite de ~4000
  // caracteres); divide em blocos terminados em fim de frase
  List<String> _speechChunks(String text, {int maxLength = 3500}) {
    if (text.length <= maxLength) return [text];
    final chunks = <String>[];
    var current = StringBuffer();
    for (final sentence in text.split(RegExp(r'(?<=[.!?])\s+'))) {
      if (current.length + sentence.length + 1 > maxLength && current.isNotEmpty) {
        chunks.add(current.toString().trim());
        current = StringBuffer();
      }
      if (sentence.length > maxLength) {
        for (var i = 0; i < sentence.length; i += maxLength) {
          chunks.add(sentence.substring(i, (i + maxLength).clamp(0, sentence.length)));
        }
        continue;
      }
      current.write('$sentence ');
    }
    if (current.isNotEmpty) chunks.add(current.toString().trim());
    return chunks;
  }

  /// Fala o texto; retorna false se outra fala começou nesse meio tempo.
  Future<bool> _speak(String text) async {
    final token = ++_speakToken;
    _lastAssistantMessage = text;
    _isSpeaking = true;
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
    await _tts.stop();
    for (final chunk in _speechChunks(text)) {
      if (token != _speakToken) return false;
      try {
        await _tts
            .speak(chunk)
            .timeout(Duration(seconds: 20 + chunk.length ~/ 10));
      } catch (_) {
        // TTS travado: interrompe a fala para o microfone não abrir por cima dela
        await _tts.stop();
        break;
      }
    }
    if (token != _speakToken) return false;
    _isSpeaking = false;
    return true;
  }

  Future<void> _speakAndResume(String text) async {
    final stillLatest = await _speak(text);
    if (stillLatest && _assistantActive) {
      await _startListening();
    }
  }

  // Estado atual da receita e da conversa, enviado para o interpretador
  RecipeAssistantContext _buildAssistantContext() {
    return RecipeAssistantService.buildContext(
      title: _titulo,
      category: _categoriaNome,
      ingredients: _loadedIngredients,
      instructions: _loadedInstructions,
      ingredientChecked: _ingredientChecked,
      instructionChecked: _instructionChecked,
      currentStepIndex: _currentStepIndex,
      currentIngredientIndex: _currentIngredientIndex,
      mode: _assistantMode,
      lastResponse: _lastAssistantMessage,
      pendingAction: _pendingAssistantAction,
      history: List.unmodifiable(_assistantHistory),
    );
  }

  void _rememberTurn(String role, String text) {
    if (text.trim().isEmpty) return;
    _assistantHistory.add(RecipeAssistantTurn(role: role, text: text));
    if (_assistantHistory.length > 12) {
      _assistantHistory.removeRange(0, _assistantHistory.length - 12);
    }
  }

  // Aplica na tela o que o assistente entendeu (marcações, passo e modo)
  void _applyAssistantIntent(RecipeAssistantIntent intent) {
    setState(() {
      for (final i in intent.checkIngredients) {
        if (i >= 0 && i < _ingredientChecked.length) _ingredientChecked[i] = true;
      }
      for (final i in intent.uncheckIngredients) {
        if (i >= 0 && i < _ingredientChecked.length) _ingredientChecked[i] = false;
      }
      for (final i in intent.checkSteps) {
        if (i >= 0 && i < _instructionChecked.length) _instructionChecked[i] = true;
      }
      for (final i in intent.uncheckSteps) {
        if (i >= 0 && i < _instructionChecked.length) _instructionChecked[i] = false;
      }
    });
    if (intent.mode != null) {
      _assistantMode = intent.mode!;
    }
    if (_loadedInstructions.isNotEmpty) {
      _currentStepIndex = intent.stepIndex.clamp(0, _loadedInstructions.length - 1);
    }
    final ingredientIndex = intent.ingredientIndex;
    if (ingredientIndex != null &&
        ingredientIndex >= 0 &&
        ingredientIndex < _loadedIngredients.length) {
      _currentIngredientIndex = ingredientIndex;
    }
    _pendingAssistantAction = intent.pendingAction;
  }

  // Interpreta a fala livre do usuário e responde com base na receita
  Future<void> _processVoiceCommand(List<String> transcricoes) async {
    if (_isProcessing || !_assistantActive) return;
    _isProcessing = true;
    final session = _assistantSession;
    var transcript = transcricoes.first;
    RecipeAssistantIntent intent;
    try {
      final (escolhida, resultado) = await _assistantService.interpretAlternatives(
        transcripts: transcricoes,
        context: _buildAssistantContext(),
      );
      transcript = escolhida;
      intent = resultado;
      assert(() {
        debugPrint('[assistente] ouvi: $transcricoes -> "$transcript" = ${intent.action} (${intent.source})');
        return true;
      }());
    } catch (_) {
      intent = RecipeAssistantIntent(
        action: 'general',
        stepIndex: _currentStepIndex,
        responseText: 'Desculpe, não consegui entender. Pode repetir de outro jeito?',
      );
    } finally {
      if (session == _assistantSession) _isProcessing = false;
    }

    // Assistente desligado/religado enquanto esperava a IA: descarta a resposta
    if (!mounted || !_assistantActive || session != _assistantSession) return;
    _rememberTurn('user', transcript);
    _applyAssistantIntent(intent);
    _rememberTurn('assistant', intent.responseText);

    if (intent.stopAssistant) {
      await _speak(intent.responseText);
      if (!mounted) return;
      setState(() {
        _assistantMenuOpen = false;
        _assistantWasActive = false;
      });
      await _stopAssistant();
      return;
    }
    await _speakAndResume(intent.responseText);
  }

  String _buildRecipeShareText() {
    final buffer = StringBuffer();
    buffer.write('Categoria:');
    if (_categoriaNome != null && _categoriaNome!.isNotEmpty) {
      buffer.write(' $_categoriaNome');
    }
    buffer.writeln();
    buffer.writeln('Título: $_titulo');
    buffer.writeln('Ingredientes:');
    for (final ingrediente in _loadedIngredients) {
      buffer.writeln('* $ingrediente');
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
    _assistantActive = false;
    _assistantSession++;
    _speakToken++;
    if (_speech.statusListener == _onSpeechStatus) _speech.statusListener = null;
    if (_speech.errorListener == _onSpeechError) _speech.errorListener = null;
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _hasChanges);
        }
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
                  // O assistente não continua ouvindo na tela de edição
                  if (_assistantActive) await _turnOffAssistant();
                  if (!context.mounted) return;
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Cadastro(recipeId: widget.recipeId),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
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
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_assistantMenuOpen || _assistantActive || _isSpeaking)
              FloatingActionButton.small(
                heroTag: 'assistant-info',
                onPressed: _mostrarInfoAssistente,
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade600,
                tooltip: 'Como usar o assistente',
                child: Icon(Icons.info_outline),
              ),
            if (_assistantMenuOpen || _assistantActive || _isSpeaking)
              SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'assistant-main',
              onPressed: _toggleAssistant,
              backgroundColor: Colors.red.shade600,
              tooltip:
                  _assistantMenuOpen
                      ? (_assistantWasActive
                          ? 'Retomar assistente'
                          : 'Ativar assistente')
                      : (_assistantActive
                          ? 'Assistente ativo'
                          : 'Ativar assistente'),
              child: Icon(
                _assistantMenuOpen
                    ? Icons.pause
                    : (_assistantActive
                        ? (_isListening ? Icons.mic : Icons.mic_none)
                        : Icons.restaurant_menu),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
