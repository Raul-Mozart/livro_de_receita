import 'package:livro_de_receita/assistant/recipe_assistant_models.dart';
import 'package:livro_de_receita/assistant/recipe_language.dart';

// Interpretador local (sem internet) da fala do usuário.
// Em vez de comparar com frases fixas, ele extrai da fala os elementos que
// importam (ingredientes citados, número de passo, negação, pergunta de
// quantidade, tempo, temperatura...) e decide a intenção usando também o
// contexto da conversa (modo atual, passo atual, o que já foi marcado).
class LocalRecipeInterpreter {
  final RecipeAssistantContext ctx;
  final List<ParsedIngredient> _ingredients;
  final List<List<String>> _stepWords;

  LocalRecipeInterpreter(this.ctx)
      : _ingredients =
            ctx.ingredients.map(RecipeLanguage.parseIngredient).toList(),
        _stepWords = ctx.instructions.map(RecipeLanguage.contentWords).toList();

  // Confiança usada para decidir se vale consultar a IA do backend
  static const double high = 0.9;
  static const double medium = 0.6;
  static const double low = 0.3;

  int get _stepCount => ctx.instructions.length;
  int get _ingredientCount => ctx.ingredients.length;
  bool get _gathering => ctx.mode == RecipeAssistantModes.ingredientes;
  bool get _cooking => ctx.mode == RecipeAssistantModes.passos;

  int get _currentStep => _clampStep(ctx.currentStepIndex);

  int _clampStep(int index) {
    if (_stepCount == 0) return 0;
    if (index < 0) return 0;
    if (index >= _stepCount) return _stepCount - 1;
    return index;
  }

  List<int> get _uncheckedIngredients => [
        for (var i = 0; i < _ingredientCount; i++)
          if (!ctx.ingredientChecked[i]) i,
      ];

  // ---------------------------------------------------------------------------
  // Ponto de entrada
  // ---------------------------------------------------------------------------

  RecipeAssistantIntent interpret(String transcript) {
    final u = _selfCorrected(_Utterance.parse(transcript));
    if (u.text.isEmpty) {
      return _result(
        'general',
        'Não consegui entender. Pode repetir, por favor?',
        confidence: low,
      );
    }

    // Reconhecimento de voz devolvendo inglês ("who is your fusion"): avisa a
    // causa em vez de só dizer que não entendeu
    if (_looksEnglish(u)) {
      return _result(
        'general',
        'O reconhecimento de voz do aparelho parece estar em inglês: ouvi "${u.raw.trim()}". '
            'Coloque o português do Brasil no idioma da digitação por voz do Google e tente de novo.',
        confidence: high,
      );
    }

    final turnOffDoubt = _ambiguousTurnOff(u);
    if (turnOffDoubt != null) return turnOffDoubt;

    if (_wantsStop(u)) {
      return _result(
        'stop_assistant',
        'Tudo bem, vou desligar o assistente. Bom proveito na cozinha!',
        stop: true,
        confidence: high,
      );
    }

    final pending = ctx.pendingAction;
    if (pending != null && pending.isNotEmpty) {
      if (_isYes(u)) return _runConfirmed(pending);
      if (_isNo(u)) {
        return _result(
          'decline',
          'Tudo bem. Quando quiser, é só falar comigo.',
          confidence: high,
        );
      }
    }

    return _greetingIntent(u) ??
        _otherDishIntent(u) ??
        _helpIntent(u, strongOnly: true) ??
        _readAllIntent(u) ??
        _stepReferenceIntent(u) ??
        _repeatIntent(u) ??
        _explainIntent(u) ??
        _clauseNavigationIntent(u) ??
        _startWithoutIntent(u) ??
        _ingredientIntent(u) ??
        _startPrepIntent(u) ??
        _completeStepIntent(u) ??
        _recipeInfoIntent(u) ??
        _navigationIntent(u) ??
        _helpIntent(u) ??
        _smalltalkIntent(u) ??
        _fallbackIntent(u);
  }

  // "oi", "e aí, beleza?" sozinhos são cumprimentos, não confirmações
  RecipeAssistantIntent? _greetingIntent(_Utterance u) {
    if (!RecipeLanguage.re(
      r'^(oi|ola|opa|e ai|eai|salve|fala|bom dia|boa tarde|boa noite|hey|alo)( assistente)?( (beleza|tudo bem|tudo bom|tudo certo|como vai|como voce esta|blz|suave|firmeza|de boa|tranquilo|tudo joia|joia))?( assistente)?$',
    ).hasMatch(u.text)) {
      return null;
    }
    return _result(
      'smalltalk',
      'Oi! Estou aqui para te ajudar com a receita ${ctx.title}. ${_contextHint()}',
      confidence: high,
    );
  }

  // Assuntos fora da receita (clima, futebol, outra receita...)
  RecipeAssistantIntent? _otherDishIntent(_Utterance u) {
    // Assunto de fora, a não ser que a frase também peça algo da receita
    // ("me distraí com a novela, onde eu parei?")
    final offTopic = u.has(
          r'chove\w*|chover|choveu|chuva|previsao do tempo|clima|futebol|jogo|time|noticia|noticias|politica|piada|musica|filme|novela|horoscopo|dolar|que horas sao|que dia e hoje',
        ) &&
        !u.has(r'receita|passo|etapa|ingrediente|parei|paramos|onde (eu )?(estou|estava)|o que (eu )?faco|preparo');
    final otherDish = RecipeLanguage.re(
      r'\b(?:como (?:se )?(?:faz|faco|fazer|prepara|preparo)|receita de|sabe fazer|me ensina a fazer|me ensina) (?:um|uma|uns|umas)\s+([a-z]+)',
    ).firstMatch(u.text);
    final otherRecipe = otherDish ??
        RecipeLanguage.re(r'\b(?:uma|outra) receita de ([a-z]+)|\breceita de ([a-z]+) (?:ai|para mim|pra mim)').firstMatch(u.text);
    var isOtherDish = false;
    if (otherRecipe != null) {
      final dish = otherRecipe.group(1) ?? otherRecipe.group(2)!;
      final titleWords = RecipeLanguage.contentWords(ctx.title);
      isOtherDish = !titleWords.any((w) => RecipeLanguage.wordsMatch(dish, w)) &&
          !_ingredients.any((i) => i.keyWords.any((k) => RecipeLanguage.wordsMatch(dish, k)));
    }
    if (!offTopic && !isOtherDish) return null;
    if (_mentions(u.words).any((m) => m.headMatched) && !isOtherDish) return null;
    return _result(
      'general',
      'Desculpe, eu só consigo ajudar com a receita ${ctx.title}. '
          'Você pode perguntar sobre os ingredientes, as quantidades ou os passos do preparo.',
      confidence: low,
    );
  }

  /// Mensagem dita quando o assistente é ativado.
  String welcomeMessage() {
    final title = ctx.title;
    // Religando no meio da receita: continua de onde parou
    if (_cooking && _stepCount > 0 && ctx.instructionChecked.contains(true)) {
      if (!ctx.instructionChecked.contains(false)) {
        return 'Você já concluiu todos os passos da receita $title. '
            'Se quiser, eu repito algum passo ou os ingredientes.';
      }
      return 'Vamos continuar a receita $title de onde paramos. ${_stepSentence(_currentStep)}';
    }
    if (_ingredientCount == 0 && _stepCount == 0) {
      return 'Vamos começar a receita $title. Ela ainda não tem ingredientes nem passos cadastrados.';
    }
    if (_ingredientCount > 0 && _uncheckedIngredients.isEmpty) {
      return 'Vamos começar a receita $title. Vejo que os ingredientes já estão separados. '
          'Quer ir para o modo de preparo?';
    }
    if (_ingredientCount == 0) {
      return 'Vamos começar a receita $title. Pode me pedir o primeiro passo quando quiser.';
    }
    return 'Vamos começar a receita $title. Você vai precisar de: '
        '${RecipeLanguage.joinPt(_ingredients.map((i) => i.spoken).toList())}. '
        'Pode falar comigo normalmente: me conte o que já pegou, '
        'pergunte quantidades ou peça para ir ao preparo.';
  }

  /// Ação oferecida na mensagem de boas-vindas (para o "sim" do usuário).
  String? welcomePendingAction() {
    if (_cooking) return null;
    if (_ingredientCount > 0 && _uncheckedIngredients.isEmpty) {
      return 'start_prep';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Sim / não / parar
  // ---------------------------------------------------------------------------

  static const String _yesWords =
      r'sim|pode|claro|bora|vamos|quero|ok|okay|beleza|isso|com certeza|manda|uhum|aham|esta bom|esta|certo|positivo|demorou|fechou|fechado|vai|perfeito|otimo|show|partiu|por favor|yes|exato|isso mesmo|pode ser|seria bom|gostaria|sigo|segue|continua|prossiga';

  bool _isYes(_Utterance u) {
    if (u.words.length > 20) return false;
    if (u.starts(r'nao|nem|agora nao|ainda nao')) return false;
    if (u.words.length <= 6 && u.has('nao|nem')) return false;
    if (!u.starts(_yesWords) && !u.has('sim|pode sim|quero sim|claro')) {
      return false;
    }
    // "vai demorar muito?" / "está quente?" começam com palavras de "sim", mas perguntam algo
    if (u.starts(r'vai|esta') && u.words.length > 2 && !u.has(r'vai la|vai em frente|esta bom|esta otimo|esta certo|sim')) {
      return false;
    }
    if (_isTimeQuestion(u) || _isTemperatureQuestion(u)) return false;
    // "sim, mas quanto de açúcar vai?" ou "pode repetir?" trazem outro pedido
    if (_mentions(u.words).isNotEmpty && !u.has('pode|sim|quero')) return false;
    if (u.has('quanto|quantos|quantas|qual|quais|como|quando|onde')) {
      return false;
    }
    if (_wantsRepeat(u) || _findStepReference(u) != null) return false;
    return true;
  }

  // Autocorreção no meio da fala: "peguei o alho, não, pera, quer dizer a cebola"
  _Utterance _selfCorrected(_Utterance u) {
    final marker = RecipeLanguage.re(
      r'\b(?:(?:nao )?(?:pera|espera)(?: ai)? )?(?:(?<!que )quer dizer|(?<=(?:nao|ou) )digo|ou melhor|melhor dizendo|na verdade|alias|corrigindo)\b|\bnao (?:pera|espera)\b',
    ).firstMatch(u.text);
    if (marker == null) return u;
    final before = RecipeLanguage.tokens(u.text.substring(0, marker.start));
    final after = u.text.substring(marker.end).trim();
    // "não, pera, ainda tô mexendo" no começo da fala é recusa, não correção
    if (before.isEmpty) {
      return RecipeLanguage.re(r'^(nao|agora nao)\b').hasMatch(u.text) || after.isEmpty
          ? u
          : _Utterance.parse(after, alreadyNormalized: true);
    }
    if (after.isEmpty) {
      return _Utterance.parse(u.text.substring(0, marker.start), alreadyNormalized: true);
    }
    // Itens que podem ser corrigidos: ingredientes e números ("um/uma" não,
    // porque aparecem em "de uma vez", "um pouco")
    int? ingredientOf(String w) {
      for (var i = 0; i < _ingredients.length; i++) {
        if (_ingredients[i].keyWords.any((k) => RecipeLanguage.matchQuality(w, k) >= 2)) return i;
      }
      return null;
    }
    bool isNumber(String w) => w != 'um' && w != 'uma' && RecipeLanguage.parseNumberToken(w) != null;
    bool isEntity(String w) => isNumber(w) || ingredientOf(w) != null;

    // Sem ingrediente/número antes do marcador não há o que corrigir
    if (!before.any(isEntity)) return u;
    final afterWords = RecipeLanguage.tokens(after);
    final firstAfter = afterWords.indexWhere(isEntity);
    // "...na verdade ainda nem comecei": nada foi trocado, é só um comentário
    if (firstAfter == -1) return u;

    var cut = before.length;
    for (var i = before.length - 1; i >= 0; i--) {
      if (isEntity(before[i])) {
        cut = i;
        // inclui o nome inteiro ("carne moída", "creme de leite")
        while (cut > 0 && (isEntity(before[cut - 1]) || (before[cut - 1] == 'de' && cut > 1 && isEntity(before[cut - 2])))) {
          cut--;
        }
        break;
      }
    }
    var prefix = before.sublist(0, cut).join(' ');
    // "separei a carne, quer dizer, a carne ainda tá congelada": o item volta a
    // ser citado com uma nova informação; o verbo de antes não vale para ele
    final corrected = ingredientOf(before[cut]);
    final replacement = ingredientOf(afterWords[firstAfter]);
    final sameItem = corrected != null && corrected == replacement;
    if (sameItem && !before.sublist(0, cut).any(isEntity)) prefix = '';
    return _Utterance.parse('$prefix $after'.trim(), alreadyNormalized: true);
  }

  bool _isNo(_Utterance u) {
    if (!u.starts(
      r'nao|agora nao|ainda nao|negativo|nem|deixa|deixa para la|melhor nao|espera|calma|pera|aguarda|depois|nao obrigado|nao precisa',
    )) {
      return false;
    }
    // "não, quanto de açúcar vai?" ou "não tenho ovo" trazem outro pedido;
    // "não, pera, ainda tô mexendo a carne" continua sendo só uma recusa
    if (_findStepReference(u) != null) return false;
    if (_mentions(u.words).isNotEmpty &&
        u.has(r'tenho|temos|peguei|separei|comprei|acabou|falta|faltou|quanto|quantos|quantas|leva|precisa|preciso|desmarca\w*|tira|marca')) {
      return false;
    }
    if (u.words.length <= 4) return true;
    return !_isQuestion(u) &&
        !u.has(r'quanto|quantos|quantas|qual|quais|como|onde|repete|ingredientes?|passo|etapa|desmarca\w*');
  }

  bool _wantsStop(_Utterance u) {
    final t = u.text;
    // Desligar/encerrar com o assistente como alvo ("desliga o assistente")
    if (RecipeLanguage.re(r'\b(desliga|desligar|desligue|encerra|encerrar|encerre|fecha|fechar|feche|parar|pare|sair d[oe]|sai d[oe])\s+(o |a )?(assistente|microfone|aplicativo|app)\b')
        .hasMatch(t)) {
      return true;
    }
    if (RecipeLanguage.re(r'^(pode |por favor )?para (o |a )?(assistente|microfone)\b').hasMatch(t)) return true;
    // Parar de escutar ("para de me escutar")
    if (RecipeLanguage.re(r'\b(parar|pare|para) de (me )?(escutar|ouvir|gravar)\b').hasMatch(t)) return true;
    // Verbo sozinho no fim da frase ("pode desligar", "já pode parar")
    if (u.words.length <= 6 &&
        RecipeLanguage.re(r'^(ok |entao |bom |obrigad\w* |ja )*(pode |ja pode |pode ja |voce pode )?(desligar|desliga|desligue|encerrar|encerra|parar|pare|sair|fechar)( agora| ja| por favor| entao| obrigad\w*| assistente)*$')
            .hasMatch(t)) {
      return true;
    }
    // Começa pedindo para desligar ("pode desligar agora, já terminei", "desliga aí")
    if (RecipeLanguage.re(r'^(ok |entao |bom |obrigad\w* |ja )*(pode |ja pode |voce pode )?(desligar|desliga|desligue|encerrar|encerra)( (agora|ja|entao|por favor|voce|ai|isso))+\b')
        .hasMatch(t)) {
      return true;
    }
    // Despedidas valem quando são a frase inteira
    if (RecipeLanguage.re(r'^(ok |entao |bom |obrigad\w* |valeu |e )*(tchau|tchauzinho|xau|ate logo|ate mais|ate a proxima|ate depois|adeus|fui)( tchau| obrigad\w*| valeu| ate mais| ate logo| e obrigad\w*| assistente)*$')
        .hasMatch(t)) {
      return true;
    }
    if (u.words.length <= 4 && u.has(r'tchau|tchauzinho|xau')) return true;
    if (u.has(
      r'por hoje (chega|e so|ja deu|deu|acabou|terminou)|chega por hoje|ja deu por hoje|terminei por hoje|nao (preciso|precisa) mais (de |do |da )(ajuda|voce|assistente)|pode ir embora|fica quieto|cala a boca',
    )) {
      return true;
    }
    return RecipeLanguage.re(r'^(para|pare|parar|chega|sair|encerrar|desligar|stop|silencio|chega obrigad\w*|chega ja|era so isso( obrigad\w*)?)$')
        .hasMatch(t);
  }

  static const Set<String> _englishWords = {
    'the', 'who', 'is', 'you', 'your', 'that', 'yeah', 'what', 'it', 'are', 'this', 'how',
    'can', 'my', 'of', 'to', 'pick', 'up', 'me', 'do', 'have', 'i', 'and', 'with', 'its',
    'he', 'she', 'they', 'we', 'was', 'be', 'if', 'for', 'at', 'on', 'just', 'get', 'got',
  };
  static const Set<String> _portugueseWords = {
    'que', 'nao', 'eu', 'ja', 'peguei', 'de', 'do', 'da', 'os', 'para', 'com', 'voce',
    'esta', 'estou', 'tenho', 'passo', 'ingredientes', 'ingrediente', 'receita', 'qual',
    'quanto', 'como', 'agora', 'pronto', 'um', 'uma', 'meu', 'minha', 'tem', 'vai',
  };

  bool _looksEnglish(_Utterance u) {
    final words = RecipeLanguage.tokens(RecipeLanguage.normalize(u.raw));
    if (words.length < 2) return false;
    if (words.any(_portugueseWords.contains)) return false;
    if (_mentions(words).isNotEmpty) return false;
    final english = words.where(_englishWords.contains).length;
    return english >= 2 && english * 2 >= words.length;
  }

  // "já pode desligar?" quando o passo atual ou o próximo manda desligar o fogo:
  // pergunta em vez de desligar o assistente por engano
  RecipeAssistantIntent? _ambiguousTurnOff(_Utterance u) {
    if (!_cooking || _stepCount == 0) return null;
    if (!RecipeLanguage.re(r'^(ok |entao |bom |ja )*(pode |ja pode |pode ja |voce pode |posso |ja posso )(desligar|desliga|desligue|apagar|apaga)( agora| ja| entao| ai)*$')
        .hasMatch(u.text)) {
      return null;
    }
    for (final s in [_currentStep, _currentStep + 1]) {
      if (s < _stepCount && RecipeLanguage.re(r'\b(deslig\w*|apag\w*)\b').hasMatch(RecipeLanguage.normalize(ctx.instructions[s]))) {
        return _result(
          'general',
          'Se for o fogo: o passo ${s + 1} diz: ${_stepText(s)}. '
              'Se você quer desligar o assistente, é só dizer sim.',
          pending: 'stop_assistant',
          confidence: high,
        );
      }
    }
    return null;
  }

  // "vamos lá sem a aveia mesmo": começa o preparo sem marcar o que falta
  RecipeAssistantIntent? _startWithoutIntent(_Utterance u) {
    if (!_gathering || _stepCount == 0) return null;
    final m = RecipeLanguage.re(
      r'\b(vamos la|bora la|bora|vamos|pode comecar|vamos comecar|comecar|comeca|vamos fazer|seguimos|segue|partiu)\b.*\bsem (o |a |os |as )?(.+)$',
    ).firstMatch(u.text);
    if (m == null) return null;
    final excluded = _mentionsWithRefs(_Utterance.parse(m.group(3)!, alreadyNormalized: true)).map((x) => x.index).toSet();
    if (excluded.isEmpty) return null;
    final toCheck = [
      for (var i = 0; i < _ingredientCount; i++)
        if (!ctx.ingredientChecked[i] && !excluded.contains(i)) i,
    ];
    final names = excluded.map((i) => _ingredients[i].name).toList();
    return _result(
      'start_prep',
      'Certo, vamos sem ${RecipeLanguage.joinPt(names)}. ${_stepSentence(0)}',
      checkIngredients: toCheck,
      mode: RecipeAssistantModes.passos,
      step: 0,
      confidence: high,
    );
  }

  RecipeAssistantIntent _runConfirmed(String action) {
    switch (action) {
      case 'start_prep':
        // No meio do preparo, confirmar não volta a receita para o passo 1
        if (_cooking && _currentStep > 0) return _goToStep(_currentStep, 'current_step');
        return _startPrep();
      case 'next_ingredient':
        return _nextIngredient();
      case 'next_step':
        return _goToStep(_currentStep + 1, 'next_step');
      case 'previous_step':
        return _goToStep(_currentStep - 1, 'previous_step');
      case 'current_step':
      case 'repeat_step':
        return _goToStep(_currentStep, 'current_step');
      case 'ingredients':
        return _listIngredients();
      case 'missing_ingredients':
        return _missingIngredients();
      case 'read_all_steps':
        return _readAllSteps();
      case 'explain_step':
        if (_stepCount == 0) {
          return _result('general', 'Essa receita ainda não tem passos de preparo cadastrados.', confidence: high);
        }
        return _explainStep(_currentStep);
      case 'stop_assistant':
        return _result(
          'stop_assistant',
          'Tudo bem, vou desligar o assistente. Bom proveito na cozinha!',
          stop: true,
          confidence: high,
        );
      default:
        // Ação oferecida pela IA que o modo local não sabe repetir: deixa a IA decidir
        return _result(
          'general',
          'Certo! Me diga com mais detalhes o que você quer fazer agora.',
          confidence: low,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Passos citados explicitamente ("passo 3", "terceiro passo", "último passo")
  // ---------------------------------------------------------------------------

  static final String _numberAlternatives = (RecipeLanguage.numberWords.keys
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length)))
      .join('|');

  _StepRef? _findStepReference(_Utterance u) {
    final t = u.text;
    // "passo" também é verbo ("passo um pouco de óleo na forma")
    final explicitAfter = RecipeLanguage.re(
      '\\b(?:passo|etapa)s?\\s+(?:o\\s+|a\\s+)?(?:numero\\s+|n\\s+)?(\\d+|$_numberAlternatives)\\b(?!\\s+(?:pouco|pouquinho|fio|camada|pitada|vez|bocado|colher|xicara|de (?!novo)))',
    ).firstMatch(t);
    if (explicitAfter != null) {
      final n = RecipeLanguage.parseNumberToken(explicitAfter.group(1)!);
      if (n != null) return _StepRef(n - 1, _stepCount);
    }

    final explicitBefore = RecipeLanguage.re(
      '\\b(\\d+|${RecipeLanguage.ordinalWords.join('|')})\\s+(?:passo|etapa)\\b',
    ).firstMatch(t);
    if (explicitBefore != null) {
      final n = RecipeLanguage.parseNumberToken(explicitBefore.group(1)!);
      if (n != null) return _StepRef(n - 1, _stepCount);
    }

    if (u.has(r'(ultimo|ultima) (passo|etapa)|(passo|etapa) final|(vai|ir|pula|pule|vamos|bora|volta|leia|le|fala) para o (ultimo|final)( logo| ai| entao| ja| por favor)*$')) {
      return _StepRef(_stepCount - 1, _stepCount);
    }
    if (u.has(
      r'(primeiro|primeira) (passo|etapa)|do (comeco|inicio|zero)|desde o (comeco|inicio)|(voltar|volta|volte|ir|vai|vamos)( la)? para o (comeco|inicio|primeiro)\b(?! (ingrediente|item))|comecar de novo|recomecar',
    )) {
      return _StepRef(0, _stepCount);
    }

    // "vai pro 4" / "volta para o dois" durante o preparo
    if (_cooking) {
      final bare = RecipeLanguage.re(
        '\\b(?:vai|volta|volte|voltar|pula|pule|pular|ir|vamos|leia|le|fala|repete) para o (\\d+|$_numberAlternatives)\\b',
      ).firstMatch(t);
      if (bare != null) {
        final n = RecipeLanguage.parseNumberToken(bare.group(1)!);
        if (n != null) return _StepRef(n - 1, _stepCount);
      }
      // "desmarca o 4", "repete o dois", "lê o 3"
      final withArticle = RecipeLanguage.re(
        '\\b(?:desmarca\\w*|desmarque|marca|marque|repete|repita|le|leia|fala|terminei|conclui|vai|volta|pula)\\s+(?:o|a)\\s+(\\d+|$_numberAlternatives)\\b(?!\\s+(?:minutos?|graus?|horas?|xicaras?|colheres?|gramas?|ovos?|unidades?))',
      ).firstMatch(t);
      if (withArticle != null) {
        final n = RecipeLanguage.parseNumberToken(withArticle.group(1)!);
        if (n != null) return _StepRef(n - 1, _stepCount);
      }
      // "tira o check do 4", "o 3 eu não terminei, desmarca"
      if (u.has(r'desmarca\w*|desmarque|tira|tire|check|marcacao|marca|marque|nao terminei|nao acabei|nao fiz')) {
        final ofNumber = RecipeLanguage.re(
          '\\b(?:do|da|no|na|o|a)\\s+(\\d+|$_numberAlternatives)\\b(?!\\s+(?:minutos?|graus?|horas?|xicaras?|colheres?|gramas?|unidades?|ovos?))',
        ).firstMatch(t);
        if (ofNumber != null) {
          final n = RecipeLanguage.parseNumberToken(ofNumber.group(1)!);
          if (n != null) return _StepRef(n - 1, _stepCount);
        }
      }
    }
    return null;
  }

  int? _relativeMove(_Utterance u) {
    final back = RecipeLanguage.re(
      r'\b(?:volta|voltar|volte|retorna|retornar|retroceder|recua|recuar)\s+(?:mais\s+)?(\d+|um|uma|dois|duas|tres|quatro|cinco)\s+(?:passos?|etapas?)\b',
    ).firstMatch(u.text);
    if (back != null) {
      return -(RecipeLanguage.parseNumberToken(back.group(1)!) ?? 1);
    }
    final forward = RecipeLanguage.re(
      r'\b(?:avanca|avancar|avance|pula|pular|pule|adianta|adiantar|segue|seguir)\s+(?:mais\s+)?(\d+|um|uma|dois|duas|tres|quatro|cinco)\s+(?:passos?|etapas?)\b',
    ).firstMatch(u.text);
    if (forward != null) {
      return RecipeLanguage.parseNumberToken(forward.group(1)!) ?? 1;
    }
    return null;
  }

  RecipeAssistantIntent? _stepReferenceIntent(_Utterance u) {
    if (_stepCount == 0) {
      if (u.has(r'passo|passos|etapa|etapas|preparo')) {
        return _result(
          'general',
          'Essa receita ainda não tem passos de preparo cadastrados.',
          confidence: high,
        );
      }
      return null;
    }

    final relative = _relativeMove(u);
    if (relative != null) {
      return _goToStep(
        _currentStep + relative,
        relative < 0 ? 'previous_step' : 'next_step',
      );
    }

    final ref = _findStepReference(u);
    if (ref == null) return null;

    if (ref.outOfRange) {
      return _result(
        'general',
        'Essa receita tem só $_stepCount ${_stepCount == 1 ? 'passo' : 'passos'}. '
            'Quer que eu leia o passo atual?',
        pending: 'current_step',
        confidence: high,
      );
    }
    final index = ref.index;

    if (_wantsUncheckStep(u)) return _uncheckStep(index);
    if (_saysStepDone(u, step: index) && !_isQuestion(u)) return _completeStep(index);
    // Só trata como pergunta de tempo/temperatura com termos explícitos
    if (u.has(r'quanto tempo|por quanto tempo|quantos minutos?|quantas horas?|demora|leva quanto')) {
      return _timeAnswer(u, onlyStep: index);
    }
    if (u.has(r'temperatura|graus?|qual (o )?fogo|que fogo|intensidade|potencia')) {
      return _temperatureAnswer(u, onlyStep: index);
    }
    if (_wantsExplanation(u)) return _explainStep(index, move: true);
    if (_mentions(u.words).isNotEmpty && (_isQuantityQuestion(u) || _isExplicitWhereQuestion(u))) {
      return null; // "quanto de açúcar vai no passo 3" -> pergunta de ingrediente
    }
    return _goToStep(index, 'go_to_step');
  }

  // ---------------------------------------------------------------------------
  // Repetir / explicar
  // ---------------------------------------------------------------------------

  bool _wantsRepeat(_Utterance u) {
    if (RecipeLanguage.re(r'^(como|o que|que|hein|ha|han|hm|hum|ahn|oi como|perdao|desculpa|repete|repita|de novo)$')
        .hasMatch(u.text)) {
      return true;
    }
    return u.has(
      r'repete|repetir|repita|repeti|de novo|novamente|outra vez|mais uma vez|nao entendi|nao ouvi|nao escutei|o que (voce|tu) (disse|falou)|que (voce|tu) (disse|falou)|como e que e|fala (de novo|outra vez)|mais devagar|pode repetir|nao peguei (o que|direito|essa)|nao consegui (ouvir|escutar|entender)|nao deu para (ouvir|entender)|perdi (essa|o que (voce )?(falou|disse))',
    );
  }

  RecipeAssistantIntent? _repeatIntent(_Utterance u) {
    if (!_wantsRepeat(u)) return null;
    if (_wantsExplanation(u)) return null;

    if (_stepCount > 0 && u.has(r'anterior|de antes|antes desse|antes deste|que era antes|o de antes')) {
      return _goToStep(_currentStep - 1, 'previous_step');
    }
    if (_stepCount > 0 && u.has(r'proximo|proxima|seguinte|que vem depois')) {
      return _goToStep(_currentStep + 1, 'next_step');
    }
    if (u.has(r'ingredientes?|o que (precisa|vai)') || _wantsIngredientList(u)) {
      return _listIngredients();
    }
    if (u.has(r'passo|etapa|parte|isso que (eu )?tenho que fazer')) {
      if (_stepCount == 0) return null;
      return _goToStep(_currentStep, 'repeat_step');
    }
    final last = ctx.lastResponse.trim();
    if (last.isNotEmpty) {
      return _result('repeat_last', last, confidence: high);
    }
    if (_cooking && _stepCount > 0) {
      return _goToStep(_currentStep, 'repeat_step');
    }
    return _result(
      'repeat_last',
      'Ainda não falei nada para repetir. ${_contextHint()}',
      confidence: medium,
    );
  }

  bool _wantsExplanation(_Utterance u) {
    return u.has(
      r'como assim|explica|explique|explicar|me explica|detalha|detalhe|detalhar|mais detalhe|detalhes|melhor esse passo|nao entendi (esse|essa|o|a|isso|como|direito esse|direito essa) ?(passo|etapa|parte|que|faz|fazer)?|como (eu )?(faco|faz|fazer|que faz|que eu faco) (isso|esse passo|essa parte|essa etapa|esse negocio|ai|isso ai)|o que (significa|quer dizer)|como funciona (esse|essa) (passo|etapa|parte)|como que e isso|o que e para fazer (nesse|neste|aqui)|o que e (que e )?(untar|preaquecer|banho maria|refogar|peneirar|sovar|polvilhar|dourar|gratinar|ponto|escaldar|marinar|reduzir|selar|incorporar|emulsionar|flambar|branquear|temperatura ambiente|homogeneo|reservar)|o que e (esse|essa|isso de|esse negocio de|essa coisa de|o tal de|a tal de) [a-z]+|o que e isso|[a-z]{4,} e o que( exatamente| e isso| seria)?$|(esse|essa) tal de [a-z]+|nunca (entendi|soube) (direito )?(o que|essa palavra|esse nome)',
    );
  }

  RecipeAssistantIntent? _explainIntent(_Utterance u) {
    if (!_wantsExplanation(u)) return null;
    final term = _glossaryTerm(u);
    if (term != null) {
      return _result('explain_step', term, confidence: high);
    }
    if (_stepCount == 0) return null;
    // "não entendi o passo anterior" / "explica o próximo"
    if (u.has(r'anterior|de antes|antes desse|antes deste')) {
      return _explainStep(_currentStep - 1, move: true);
    }
    if (u.has(r'proximo|proxima|seguinte|que vem depois')) {
      return _explainStep(_currentStep + 1, move: true);
    }
    if (_gathering && !u.has(r'passo|etapa|preparo')) {
      final last = ctx.lastResponse.trim();
      if (last.isNotEmpty && _uncheckedIngredients.isNotEmpty) {
        final next = _uncheckedIngredients.first;
        return _result(
          'explain_step',
          'Agora é a hora de separar os ingredientes. O próximo é ${_ingredients[next].spoken}. '
              'Quando pegar, é só me avisar.',
          ingredientIndex: next,
          confidence: medium,
        );
      }
    }
    return _explainStep(_currentStep);
  }

  // Pequeno glossário de termos comuns em receitas
  static const Map<String, String> _glossary = {
    'untar': 'Untar é passar uma camada fina de gordura, como manteiga ou óleo, na forma, e depois polvilhar farinha, para a massa não grudar.',
    'preaquecer': 'Preaquecer é ligar o forno antes, na temperatura indicada, por uns 10 a 15 minutos, para ele já estar quente quando a massa entrar.',
    'banho maria': 'Banho-maria é aquecer o alimento num recipiente colocado dentro de outro com água quente, para cozinhar devagar e sem queimar.',
    'refogar': 'Refogar é dourar rapidamente os ingredientes em pouca gordura, mexendo sempre, em fogo médio.',
    'peneirar': 'Peneirar é passar os ingredientes secos por uma peneira, para tirar os grumos e deixar a massa mais leve.',
    'sovar': 'Sovar é amassar e esticar a massa com as mãos até ela ficar lisa e elástica.',
    'polvilhar': 'Polvilhar é espalhar uma camada fina de um ingrediente em pó por cima, como farinha ou açúcar.',
    'dourar': 'Dourar é cozinhar até o alimento ficar com a superfície levemente dourada.',
    'gratinar': 'Gratinar é levar ao forno bem quente para formar uma casquinha dourada por cima.',
    'escaldar': 'Escaldar é mergulhar rapidamente o alimento em água fervente.',
    'marinar': 'Marinar é deixar o alimento descansando num tempero líquido para pegar sabor.',
    'reduzir': 'Reduzir é deixar o líquido ferver até evaporar uma parte e engrossar.',
    'selar': 'Selar é dourar rapidamente a carne em fogo alto, por todos os lados.',
    'incorporar': 'Incorporar é misturar delicadamente até o ingrediente se juntar por completo à massa.',
    'palito': 'O teste do palito é espetar um palito no meio do bolo: se ele sair limpo, sem massa grudada, o bolo está assado.',
    'temperatura ambiente': 'Temperatura ambiente quer dizer que o ingrediente não deve estar gelado; tire da geladeira um pouco antes.',
    'fogo baixo': 'Fogo baixo é a chama mais fraca do fogão, para cozinhar devagar sem queimar.',
    'homogeneo': 'Homogêneo quer dizer bem misturado, com a mesma cor e textura por igual, sem pedaços ou partes separadas.',
    'reservar': 'Reservar é deixar a preparação separada, esperando, até a hora de usar nos próximos passos.',
    'em neve': 'Claras em neve são claras batidas até ficarem bem firmes e brancas.',
  };

  String? _glossaryTerm(_Utterance u) {
    if (!u.has(r'o que (e|significa|quer dizer|seria)|que e (isso|esse negocio)|e o que|como (faz|faco) para|explica o que e|ate quando|nunca (entendi|soube)')) {
      return null;
    }
    for (final entry in _glossary.entries) {
      // Cada palavra do termo precisa aparecer, aceitando flexões ("gratina" ~ "gratinar")
      final keyWords = RecipeLanguage.tokens(entry.key);
      final found = keyWords.every((k) => u.words.any(
            (w) => w == k || (w.length >= 4 && (RecipeLanguage.sameVerb(w, k) || RecipeLanguage.wordsMatch(w, k))),
          ));
      final preheat = entry.key == 'preaquecer' && u.has(r'pre aquec\w*|preaquec\w*');
      if (found || preheat) return entry.value;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Ingredientes
  // ---------------------------------------------------------------------------

  static const String _acquireStrong =
      r'pe(g|gu|qu)ei|pegamos|pego|separei|separamos|separado|separada|separados|separadas|tenho|temos|estou com|estamos com|consegui|achei|encontrei|comprei|esta aqui|estao aqui|aqui esta|aqui estao|na mao|em maos|na bancada|esta comigo|estao comigo|ja separei|tirei|ja esta separad[oa]s?|ja peguei|ja tenho|marca|marcar|marque|pode marcar|confere|check|ja esta|ja estao|deixei|(acabei|terminei) de (pegar|separar|buscar|comprar)|consegui (pegar|separar|achar)|trouxe|busquei|fui buscar';
  static const String _acquireWeak =
      r'ok|okay|pronto|pronta|prontinho|beleza|feito|certo|coloquei|esse ja|esse tambem|esse ai|ja foi|terminei|acabei';

  // "ingrediente 5", "primeiro ingrediente", "último ingrediente"
  // Retorna índice do ingrediente -> posição (palavra) onde foi citado
  Map<int, int> _ingredientNumberRefs(String text) {
    final result = <int, int>{};
    if (_ingredientCount == 0) return result;
    void add(String? token, int offset) {
      final n = token == null ? null : RecipeLanguage.parseNumberToken(token);
      if (n != null && n >= 1 && n <= _ingredientCount) {
        result.putIfAbsent(n - 1, () => _wordIndexAt(text, offset));
      }
    }

    for (final m in RecipeLanguage.re('\\b(?:ingrediente|item)\\s+(?:numero\\s+)?(\\d+|$_numberAlternatives)\\b').allMatches(text)) {
      add(m.group(1), m.start);
    }
    for (final m in RecipeLanguage.re('\\b(\\d+|${RecipeLanguage.ordinalWords.join('|')})\\s+(?:ingrediente|item)\\b').allMatches(text)) {
      add(m.group(1), m.start);
    }
    final last = RecipeLanguage.re(r'\b(ultimo|ultima) (ingrediente|item)\b').firstMatch(text);
    if (last != null) add('$_ingredientCount', last.start);
    return result;
  }

  // Ingredientes citados pelo nome ou pelo número
  List<_Mention> _mentionsWithRefs(_Utterance u) {
    final byName = _mentions(u.words);
    final refs = _ingredientNumberRefs(u.text)
        .entries
        .where((e) => !byName.any((m) => m.index == e.key))
        .map((e) => _Mention(e.key, 2, true, <int>{e.value}));
    return [...byName, ...refs];
  }

  // Negações de posse; um "não" solto ("não esquece do fermento") não conta
  static const String _lack =
      r'(ainda )?nao (tenho|temos|peguei|pegamos|achei|encontrei|consegui|comprei|separei|estou com|tem|esta|estao|ha|vou ter|tinha|trouxe)|ainda nao|faltou|falta|faltando|faltam|acabou|acabaram|estou sem|to sem|sem (o|a|os|as)|esqueci (de pegar|de comprar|de separar|o|a|os|as)|esqueceram|desmarca\w*|desmarque|tira (a |o )?(marca|marcacao|check)|tira|tire|tirar|retira|remove|cade|onde esta|perdi|estragou|estragad[oa]|vencid[oa]|lixo|jogu?ei fora|me enganei|enganei|nao era|nem (o|a|os|as)|nao$|congelad[oa]s?|(esta|estao|ta|tao) (no|na) (congelador|freezer|mercado)';

  static const String _lackCooking =
      r'nao (tenho|temos|peguei|achei|encontrei|comprei|separei|tem|ha|vou ter|tinha)|faltou|falta|faltando|acabou|acabaram|estou sem|to sem|esqueci de comprar|estragou|estragad[oa]|vencid[oa]|desmarca\w*|desmarque|me enganei';

  bool _isQuantityQuestion(_Utterance u) {
    if (u.has(
      r'quanto tempo|quantos (passos?|minutos?|graus?|ingredientes?|itens?|pedacos?|cubos?|lados?|pessoas?)|quantas (etapas?|horas?|partes?|rodelas?|fatias?|vezes|camadas?|tiras?|porcoes|pessoas?|bolinhas?)|demora quanto',
    )) {
      return false;
    }
    return u.has(
      r'quanto|quantos|quantas|quanta|quantidade|qual a medida|que medida|medida|vai quanto|e quanto|quanto que|quantas xicaras|quantas colheres|quantos gramas|que quantidade|quanto eu (coloco|uso|ponho|boto)|mede|medir',
    );
  }

  bool _isWhereUsedQuestion(_Utterance u) {
    return u.has(
      r'(quando|em que|em qual|qual|que|onde|na hora de|em que momento|qual momento|qual hora|que hora|em que parte) .{0,25}\b(uso|usa|usar|usamos|coloco|colocar|coloca|ponho|por|boto|bota|adiciono|adicionar|adiciona|acrescento|acrescentar|acrescenta|entra|entram|junto|juntar|misturo|misturar|vai|vao|bato|bater|derreto|derreter|usado|usada|utilizo|utilizar|aparece)\b|em que passo|em qual passo|qual passo|que passo|em que etapa|qual etapa|em que momento',
    );
  }

  bool _isExplicitWhereQuestion(_Utterance u) => u.has(
        r'em que (parte|passo|momento|etapa|hora)|em qual (parte|passo|momento|etapa)|que (parte|passo|momento|etapa)|qual (parte|passo|momento|etapa)|quando (eu )?(uso|coloco|ponho|boto|adiciono|acrescento|junto|misturo)|(entra|entram|vai|vao|coloco|ponho|uso|adiciono|acrescento) quando',
      );

  // "coloco o queijo agora?", "já ponho o macarrão?": compara com o passo atual
  RecipeAssistantIntent? _placementTimingAnswer(_Utterance u, List<_Mention> mentions) {
    if (mentions.length != 1 || _stepCount == 0) return null;
    if (!u.has(r'coloco|ponho|boto|adiciono|acrescento|junto|jogo|misturo|uso|entra|vai|despejo')) return null;
    if (u.has(_acquireStrong) || u.has(_lack)) return null; // "peguei o óleo, já vai"
    final ing = _ingredients[mentions.first.index];
    // "ponho mais sal?": ajuste de gosto, a receita não define
    if (u.has(r'(coloco|ponho|boto|adiciono|acrescento|jogo) (um pouco )?(mais|menos)|mais um pouco|um pouco mais')) {
      return _result(
        'ingredient_info',
        'A receita pede ${ing.spoken}. Se achar que precisa, acrescente aos poucos e vá provando.',
        confidence: low,
      );
    }
    if (!u.has(r'agora|ja|nesse passo|neste passo|aqui|ainda|nessa hora|nesse momento')) return null;
    final steps = _stepsUsingIngredient(mentions.first.index);
    final name = _capitalize(ing.name);
    if (steps.isEmpty) {
      return _result('ingredient_info', 'A receita não diz em que passo usar ${ing.name}.', confidence: medium);
    }
    if (_gathering) {
      return _result(
        'ingredient_info',
        'Primeiro separe os ingredientes. $name entra no passo ${steps.first + 1}: ${_stepText(steps.first)}.',
        confidence: high,
      );
    }
    if (steps.contains(_currentStep)) {
      return _result('ingredient_info', 'Sim, $name entra neste passo: ${_stepText(_currentStep)}.', confidence: high);
    }
    final later = steps.where((s) => s > _currentStep).toList();
    if (later.isNotEmpty) {
      return _result(
        'ingredient_info',
        'Ainda não. $name entra no passo ${later.first + 1}: ${_stepText(later.first)}.',
        confidence: high,
      );
    }
    return _result(
      'ingredient_info',
      '$name já foi usado no passo ${steps.last + 1}: ${_stepText(steps.last)}.',
      confidence: high,
    );
  }

  bool _isPresenceQuestion(_Utterance u) {
    return u.has(
      r'leva|levam|tem|vai|precisa|preciso de|usa|usar|entra|e com|precisa de|vem|inclui|contem|e para (colocar|usar|por)|coloca|tem que ter',
    ) || RecipeLanguage.re(r'^e (o|a|os|as) ').hasMatch(u.text);
  }

  bool _isSubstitutionQuestion(_Utterance u) {
    return u.has(
      r'trocar|troco|troca|substituir|substituo|substitui|substituto|no lugar d[oae]s?|em vez d[oae]s?|ao inves d[oae]s?|posso usar|da para usar|serve|funciona com|da para fazer sem|posso fazer sem|fica bom (com|sem)|alternativa|pode ser|sera que pode|tanto faz|qualquer (um|uma|tipo)',
    );
  }

  bool _saysAll(_Utterance u) => u.has(
        r'tudo|todos|todas|todos os ingredientes|todos os itens|a lista toda|a lista inteira|completo|completa|o resto|o restante|os outros|as outras',
      );

  RecipeAssistantIntent? _ingredientIntent(_Utterance u) {
    if (_ingredientCount == 0) {
      if (u.has(r'ingredientes?')) {
        return _result(
          'ingredients',
          'Essa receita ainda não tem ingredientes cadastrados.',
          confidence: high,
        );
      }
      return null;
    }

    final mentions = _mentionsWithRefs(u);
    final stepWord = u.has(r'passo|passos|etapa|etapas');

    // Contagem e listas
    if (u.has(r'quant(os|as) (ingredientes|itens|coisas)')) {
      if (u.has(r'falta|faltam|resta|restam|ainda')) return _missingIngredients();
      return _result(
        'recipe_info',
        'A receita tem $_ingredientCount ${_ingredientCount == 1 ? 'ingrediente' : 'ingredientes'}.',
        confidence: high,
      );
    }

    // "qual é o último ingrediente?", "qual o terceiro ingrediente?"
    final numberRefs = _ingredientNumberRefs(u.text);
    if (numberRefs.isNotEmpty && _isQuestion(u) && !u.has(r'desmarca\w*|marca|marque|tira|peguei|tenho')) {
      final parts = numberRefs.keys
          .map((i) => 'o ingrediente ${i + 1} é ${_ingredients[i].spoken}')
          .toList();
      return _result(
        'ingredient_info',
        '${_capitalize(RecipeLanguage.joinPt(parts))}.',
        ingredientIndex: numberRefs.keys.first,
        confidence: high,
      );
    }

    // Perguntas sobre um ingrediente específico
    if (mentions.isNotEmpty) {
      // "quanto tempo a carne cozinha?" é pergunta de tempo, não de quantidade
      if ((_isTimeQuestion(u) && !_isExplicitWhereQuestion(u)) || _isTemperatureQuestion(u)) return null;
      if (_isSubstitutionQuestion(u)) {
        return _substitutionAnswer(mentions);
      }
      if (_isQuantityQuestion(u)) return _quantityAnswer(mentions);
      final timing = _placementTimingAnswer(u, mentions);
      if (timing != null) return timing;
      if (_isExplicitWhereQuestion(u) || (_isWhereUsedQuestion(u) && !_sayAcquired(u))) {
        return _whereUsedAnswer(mentions);
      }
    }

    // Afirmações: peguei / não tenho / tudo menos...
    final statement = _ingredientStatement(u);
    if (statement != null) return statement;

    if (mentions.isNotEmpty) {
      // Durante o preparo, "já refoguei a cebola" é conclusão do passo e
      // "o frango eu ainda não cozinhei" é passo não feito
      if (_cooking && !_isQuestion(u) && _saysStepDone(u)) return null;
      if (_cooking && (_negatedStepVerb(u) || _wantsUncheckStep(u))) return null;
      // Só o nome do ingrediente ("e a farinha?") também é pergunta sobre ele
      bool namesIngredient(String w) => mentions.any(
            (m) => _ingredients[m.index].keyWords.any((k) => RecipeLanguage.wordsMatch(w, k)),
          );
      final onlyNames = u.content.every(namesIngredient);
      // Pergunta de preparo que cita o ingrediente ("tem que descascar a batata?",
      // "corto a batata de que jeito?"): responde com o passo, sem "sim, leva"
      final otherWords = u.content
          .where((w) => !namesIngredient(w) && !RecipeLanguage.weakDescriptors.contains(w))
          .toList();
      final askingNextToFetch = _gathering && u.has(r'proximo|proxima|seguinte|pego|pegar|busco|buscar|separo|separar');
      if (!onlyNames &&
          !askingNextToFetch &&
          otherWords.isNotEmpty &&
          !_isPresenceQuestion(u) &&
          (mentions.length > 1 || _variantPhrase(mentions.first, u) == null)) {
        final step = _bestMatchingStep(u);
        if (step != null && _stepMatchScore(u, step) >= 2) {
          return _result('explain_step', 'No passo ${step + 1}: ${_stepText(step)}.', confidence: medium);
        }
      }
      if (_isPresenceQuestion(u) && otherWords.isNotEmpty && (mentions.length > 1 || _variantPhrase(mentions.first, u) == null)) {
        final step = _bestMatchingStep(u);
        final verbOutsideIngredient = otherWords.any((w) => _stepWords.any((sw) => sw.any((s) => RecipeLanguage.sameVerb(w, s))));
        if (step != null && verbOutsideIngredient && _stepMatchScore(u, step) >= 2) {
          return _result('explain_step', 'No passo ${step + 1}: ${_stepText(step)}.', confidence: medium);
        }
      }
      if (!askingNextToFetch && (_isPresenceQuestion(u) || _isQuestion(u) || onlyNames)) {
        return _presenceAnswer(mentions, u);
      }
    }

    // "qual o próximo ingrediente?" fala só o próximo, não a lista inteira;
    // "depois do leite condensado, qual o próximo?" parte do item citado
    if (!stepWord &&
        u.has(r'proximo|proxima|seguinte|qual mais|mais algum|(pego|pegar|separo|busco) o que') &&
        (_gathering || u.has(r'ingredientes?|itens?'))) {
      final after = u.has(r'depois (do|da|dos|das|de)') && mentions.isNotEmpty ? mentions.first.index : null;
      return _nextIngredient(after: after);
    }

    if (_wantsMissingIngredients(u)) return _missingIngredients();
    // "o que eu pego primeiro?", "por onde eu começo?" enquanto separa
    if (_gathering &&
        !stepWord &&
        u.has(r'(o que|qual) (eu )?(pego|pegar|separo|separar)( primeiro| agora)?|qual (e )?o primeiro|por onde (eu )?(comeco|comecar)|cade o resto|o que mais (eu )?(pego|falta)')) {
      final remaining = _uncheckedIngredients;
      if (remaining.isEmpty) return _allIngredientsReady();
      return _result(
        'next_ingredient',
        'Comece separando ${_ingredients[remaining.first].spoken}.'
            '${remaining.length > 1 ? ' Depois ${RecipeLanguage.joinPt(remaining.skip(1).take(3).map((i) => _ingredients[i].name).toList())}${remaining.length > 4 ? ', e o resto' : ''}.' : ''}',
        ingredientIndex: remaining.first,
        confidence: high,
      );
    }

    if (!stepWord && _wantsIngredientList(u)) return _listIngredients();

    if (mentions.isEmpty && _isPresenceQuestion(u) && !stepWord) {
      final absent = _absentIngredientAnswer(u);
      if (absent != null) return absent;
    }

    // "próximo" enquanto separa os ingredientes = próximo ingrediente
    // ("outro" só quando é o pedido inteiro: "outro", "manda outro")
    if (_gathering &&
        !stepWord &&
        !u.has(r'preparo|cozinhar|comecar') &&
        (u.has(r'proximo|proxima|seguinte|e agora|e depois|mais algum|qual mais') ||
            RecipeLanguage.re(r'^(e )?(o )?(manda )?outro( ingrediente)?$').hasMatch(u.text))) {
      return _nextIngredient();
    }
    return null;
  }

  bool _sayAcquired(_Utterance u) =>
      !_isQuestion(u) && u.has(_acquireStrong) && !u.has(_lack);

  bool _wantsMissingIngredients(_Utterance u) {
    if (u.has(r'passo|passos|etapa|etapas|forno|assar|terminar o bolo|ficar pronto|pela frente|acabar|terminar')) {
      return false;
    }
    if (u.has(r'falta|faltam|faltando|faltou|resta|restam|ainda preciso|preciso pegar|tenho que pegar|ainda tenho que')) {
      // "falta o açúcar" com ingrediente citado é tratado como pendência dele
      if (_mentionsWithRefs(u).isNotEmpty) return false;
      return _gathering || u.has(r'pegar|separar|comprar|buscar|ingredientes?|itens|item|coisas?');
    }
    if (u.has(
      r'(o que|quais|qual) (mais )?(ainda )?(eu )?(nao peguei|nao marquei|preciso pegar|tenho que pegar)|esqueci (algo|alguma coisa|de pegar|de marcar|de marca)|(alguma coisa|algum|alguma|algo) que (eu )?(ainda )?nao (marquei|peguei|separei)|(ver|conferir|checar) se (esta|tem|ja esta) tudo|que (eu )?(ainda )?nao (peguei|marquei|separei)|ficou (alguma coisa|algo|algum|alguma) (para tras|da lista|sem marcar)',
    )) {
      return true;
    }
    // "será que já peguei tudo?" é conferência, não afirmação
    return u.has(r'(ja )?(peguei|tenho|separei) tudo') &&
        u.has(r'sera|confere|conferir|mesmo|certeza|ver se');
  }

  bool _wantsIngredientList(_Utterance u) {
    if (u.has(r'ingredientes?|itens')) {
      return !u.has(_acquireStrong) || _isQuestion(u);
    }
    if (u.has(r'lista') && !u.has(r'passo|etapa|preparo')) return true;
    return u.has(
      r'o que (eu )?(preciso|precisa|precisamos|vou precisar|vai precisar|vai|leva|levam|usa|uso|tem|entra|entram)\b(?! (fazer|agora|depois|acontecer|demorar))|o que (eu )?(vou|vamos|tenho que|preciso) (usar|usa|precisar|comprar|pegar|separar)|as coisas que (vai|vao|iam|ia|leva|levam|precisa|preciso)|coisas? (que )?(vai|vao|iam|leva) (no|na|nesse|nessa)|tudo (o )?que (vai|leva|precisa|entra|usa|iam|ia|vao)|do que (eu )?preciso|lista de compras',
    );
  }

  // Verbos de "pegar/ter" que valem também durante o preparo
  static const String _acquireGathering =
      r'pe(g|gu|qu)ei|pegamos|separei|separamos|tenho|temos|comprei|achei|encontrei|trouxe|busquei|consegui (pegar|separar|achar)|(acabei|terminei) de (pegar|separar|buscar|comprar)|marca|marcar|marque|pode marcar';

  RecipeAssistantIntent? _ingredientStatement(_Utterance u) {
    final text = u.text;
    // Exceções: "peguei tudo menos o chocolate", "só falta o creme de leite"
    final exceptionMatch = RecipeLanguage.re(
      r'\b(menos|exceto|tirando|fora|com excecao d[oae]s?|so nao|so falta|so faltou|so esta faltando)\b',
    ).firstMatch(text);
    final mainText = exceptionMatch == null ? text : text.substring(0, exceptionMatch.start).trim();
    final exceptText = exceptionMatch == null ? '' : text.substring(exceptionMatch.end).trim();
    final main = _Utterance.parse(mainText, alreadyNormalized: true);
    final exceptMentions = exceptText.isEmpty
        ? <int>[]
        : _mentionsWithRefs(_Utterance.parse(exceptText, alreadyNormalized: true))
            .map((m) => m.index)
            .toList();

    // Durante o preparo, só negações de posse contam ("não tenho", "acabou");
    // "falta cortar", "faltou sal, tá sem gosto" ou "acabou a água, ponho mais?"
    // falam do preparo ou do sabor, não de ingrediente que falta
    var negSpans = _cueSpans(
      main.text,
      _cooking ? _lackCooking : _lack,
      exclude: r'nao (sei|entendi)|sem problema',
    );
    if (_cooking) {
      if (main.has(r'gosto|sabor|sem graca|insosso|tempero|ponho mais|coloco mais|boto mais|tem problema|posso|pode|e agora|faco o que')) {
        negSpans = [];
      } else {
        final words = main.words;
        negSpans = negSpans.where((s) {
          var next = s.end + 1;
          if (next < words.length && words[next] == 'de') next++;
          return !(next < words.length && RecipeLanguage.re(r'^[a-z]{3,}(ar|er|ir)$').hasMatch(words[next]) && words[next] != 'acucar');
        }).toList();
      }
    }
    var posPattern = _cooking
        ? _acquireGathering
        : (_gathering ? '$_acquireStrong|$_acquireWeak' : _acquireStrong);
    if (_gathering) {
      // "tomate tem aqui", "só a cebola", "o chuchu também" (logo depois de "marquei ...")
      posPattern += r'|tem aqui|aqui tem|tem (o |a )?[a-z]+( [a-z]+)? aqui|so (o|a|os|as)';
      if (RecipeLanguage.normalize(ctx.lastResponse).contains('marquei')) posPattern += '|tambem';
    }
    final posSpans = _cueSpans(main.text, posPattern)
        .where((p) => !negSpans.any((n) => p.overlaps(n)))
        .toList();
    final positive = posSpans.isNotEmpty && !main.has(r'tenho que|tem que|temos que');
    final negative = negSpans.isNotEmpty;
    final mainMentions = _mentionsWithRefs(main);

    // Planos e conferências ("vou pegar tudo", "será que já peguei tudo?",
    // "entendi tudo") não são afirmações de que o item já está separado
    if (main.has(
      r'(vou|vamos|quero|preciso|tenho que|temos que|foi|foram|vai|vao) (pegar|separar|buscar|comprar)|sera que (eu )?(ja )?(peguei|tenho|separei|tem tudo|esta tudo)|(confere|conferir|ver se|checar se) (se )?(eu )?(ja )?(peguei|tenho|separei|esta tudo|tem tudo)|entendi tudo|anotei|anota',
    )) {
      return null;
    }
    // "já peguei tudo" / "tenho todos os ingredientes" (com ou sem exceções)
    final strongAll = _cueSpans(main.text, _acquireStrong).isNotEmpty ||
        main.has(r'(esta|estao) tudo (aqui|separado|pronto|na mesa|na bancada)|tudo (aqui|separado|pronto|separadinho)');
    if (positive &&
        strongAll &&
        !negative &&
        (_saysAll(main) || (mainMentions.isEmpty && main.has(r'ingredientes|itens|as coisas')))) {
      return _allAcquired(exceptMentions);
    }
    if (exceptMentions.isNotEmpty && u.has(r'so falta|so faltou|so esta faltando')) {
      return _allAcquired(exceptMentions);
    }

    if (mainMentions.isEmpty) {
      // "peguei a salsinha" / "separei os copos": item que não é ingrediente da receita
      final unknown = positive ? _unknownAcquiredItem(main, u) : null;
      if (unknown != null) {
        final remaining = _uncheckedIngredients;
        return _result(
          'ingredient_info',
          'Não encontrei $unknown entre os ingredientes desta receita.'
              '${remaining.isEmpty ? '' : ' Ainda falta pegar: ${RecipeLanguage.joinPt(remaining.take(4).map((i) => _ingredients[i].spoken).toList())}${remaining.length > 4 ? ', entre outros' : ''}.'}',
          confidence: low,
        );
      }
      // Confirmação ("peguei", "pronto", "tenho sim") vale para o ingrediente atual
      if (_gathering && _isShortAcknowledgement(u)) {
        final current = _resolveCurrentIngredient();
        if (current == -1) return _startPrep();
        return _checkIngredients([current]);
      }
      return null;
    }
    if (!positive && !negative) return null;
    // "o frango eu ainda não cozinhei" fala do passo, não do ingrediente
    if (_cooking && _negatedStepVerb(u)) return null;

    // Cada ingrediente segue a pista mais próxima ("peguei" ou "acabou");
    // se o mesmo ingrediente aparece de novo, vale a última menção.
    final cues = <_Span>[...posSpans, ...negSpans];
    // Orações separadas por "mas/porém" não emprestam pistas uma para a outra
    final boundaries = _cueSpans(main.text, r'mas|porem|so que|entretanto|contudo').map((s) => s.start).toList();
    int clauseOf(int position) => boundaries.where((b) => b < position).length;
    final decided = <int, bool>{};
    final ordered = [...mainMentions]..sort((a, b) => a.firstPosition.compareTo(b.firstPosition));
    _Mention? previous;
    for (final m in ordered) {
      final pos = m.firstPosition;
      // "peguei o frango e as batatas, falta o alho": item ligado por "e/também"
      // ao anterior, sem pista no meio, segue o mesmo sentido
      if (previous != null && decided.containsKey(previous.index)) {
        final prevEnd = previous.positions.isEmpty ? previous.firstPosition : previous.positions.reduce((a, b) => a > b ? a : b);
        final between = prevEnd + 1 < pos ? main.words.sublist(prevEnd + 1, pos) : <String>[];
        final cueBetween = cues.any((c) => c.start > prevEnd && c.start < pos);
        // "...e a manteiga tá no congelador": estado dito logo depois do item vale para ele
        final mEnd = m.positions.isEmpty ? pos : m.positions.reduce((a, b) => a > b ? a : b);
        final followingState = negSpans.any((c) => c.start > mEnd && c.start <= mEnd + 2) &&
            RecipeLanguage.re(r'\b(esta|estao|ta|tao) (no|na)\b|congelad|estragad|estragou|vencid|acabou|acabaram|lixo')
                .hasMatch(main.words.skip(mEnd + 1).take(4).join(' '));
        if (!cueBetween &&
            !followingState &&
            between.any((w) => w == 'e' || w == 'tambem') &&
            between.every((w) => const {'e', 'tambem', 'o', 'a', 'os', 'as', 'um', 'uma', 'de', 'do', 'da'}.contains(w))) {
          decided[m.index] = decided[previous.index]!;
          previous = m;
          continue;
        }
      }
      previous = m;
      _Span? best;
      var bestDistance = 1 << 30;
      for (final c in cues) {
        var distance = pos < c.start ? c.start - pos : (pos > c.end ? pos - c.end : 0);
        if (clauseOf(c.start) != clauseOf(pos)) distance += 100;
        final preferPreceding = distance == bestDistance && best != null && c.start < pos && best.start > pos;
        if (distance < bestDistance || preferPreceding) {
          best = c;
          bestDistance = distance;
        }
      }
      if (best != null) decided[m.index] = posSpans.contains(best);
    }
    final check = decided.entries.where((e) => e.value).map((e) => e.key).toList()..sort();
    final uncheck = decided.entries.where((e) => !e.value).map((e) => e.key).toList()..sort();

    // Durante o preparo, só responde aqui se algo realmente muda
    if (_cooking) {
      final changes = check.any((i) => !ctx.ingredientChecked[i]) ||
          uncheck.any((i) => ctx.ingredientChecked[i]);
      if (!changes) {
        if (check.isEmpty || uncheck.isNotEmpty) return null;
        final names = check.map((i) => _ingredients[i].name).toList();
        return _result(
          'check_ingredients',
          '${_capitalize(RecipeLanguage.joinPt(names))} já ${check.length == 1 ? 'estava marcado' : 'estavam marcados'}. ${_contextHint()}',
          confidence: high,
        );
      }
    }
    if (check.isNotEmpty) return _checkIngredients(check, uncheck: uncheck);
    if (uncheck.isNotEmpty) return _uncheckIngredients(uncheck);
    return null;
  }

  RecipeAssistantIntent? _allAcquired(List<int> exceptions) {
    if (exceptions.isEmpty) {
      if (_cooking && _uncheckedIngredients.isEmpty) return null;
      return _cooking ? _checkIngredients(_uncheckedIngredients) : _startPrep();
    }
    final toCheck = [
      for (var i = 0; i < _ingredientCount; i++)
        if (!exceptions.contains(i) && !ctx.ingredientChecked[i]) i,
    ];
    final toUncheck = exceptions.where((i) => ctx.ingredientChecked[i]).toList();
    return _checkIngredients(toCheck, uncheck: toUncheck, missingFocus: exceptions.toList()..sort());
  }

  // Trechos da fala (em posições de palavra) que casam com um padrão
  List<_Span> _cueSpans(String text, String pattern, {String? exclude}) {
    final excluded = exclude == null
        ? const <RegExpMatch>[]
        : RecipeLanguage.re(r'\b(?:' + exclude + r')\b').allMatches(text).toList();
    final spans = <_Span>[];
    for (final m in RecipeLanguage.re(r'\b(?:' + pattern + r')\b').allMatches(text)) {
      if (excluded.any((e) => m.start < e.end && e.start < m.end)) continue;
      spans.add(_Span(_wordIndexAt(text, m.start), _wordIndexAt(text, m.end - 1)));
    }
    return spans;
  }

  static int _wordIndexAt(String text, int offset) =>
      ' '.allMatches(text.substring(0, offset.clamp(0, text.length))).length;

  // "não cozinhei", "ainda não refoguei": verbo de algum passo negado
  bool _negatedStepVerb(_Utterance u) {
    if (u.has(r'marquei errado|marcou errado|nao era para marcar')) return true;
    for (final m in RecipeLanguage.re(r'\b(?:nao|nem) (?:\w+ )?([a-z]{4,}(?:ei|i))\b').allMatches(u.text)) {
      final verb = m.group(1)!;
      if (_notCompletionVerbs.contains(verb)) continue;
      for (final words in _stepWords) {
        if (words.any((w) => RecipeLanguage.sameVerb(verb, w))) return true;
      }
    }
    return false;
  }

  static const String _nonIngredientPossession =
      r'tenho que|tem que|temos que|(estou|estamos) com (pressa|duvida|fome|medo|calor|frio|sono|problema)|(tenho|temos) (uma |um )?(pergunta|duvida|tempo|problema|pressa)|temos tempo|tenho tempo';

  // Objeto logo depois de "peguei/separei/comprei..." que não é ingrediente
  // ("peguei a salsinha", "separei os copos"); null se for só confirmação
  String? _unknownAcquiredItem(_Utterance main, _Utterance original) {
    if (main.has(_nonIngredientPossession)) return null;
    final cue = RecipeLanguage.re(
      r'\b(pe(g|gu|qu)ei|separei|separamos|comprei|achei|encontrei|trouxe|busquei|ja tenho|tenho|temos|estou com)\b',
    ).firstMatch(main.text);
    if (cue == null) return null;
    final words = RecipeLanguage.tokens(main.text.substring(cue.end));
    const skip = {'o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas', 'ja', 'tambem', 'todo', 'toda', 'de', 'do', 'da'};
    const acknowledgement = {
      'sim', 'aqui', 'isso', 'esse', 'essa', 'esses', 'essas', 'ele', 'ela', 'eles', 'elas', 'tudo',
      'todos', 'todas', 'pronto', 'ok', 'certo', 'agora', 'ai', 'la', 'em', 'na', 'no', 'mao',
      'suave', 'fechou', 'tranquilo', 'demorou', 'firmeza', 'boa', 'beleza', 'bora', 'logo',
      'resto', 'restante', 'outros', 'outras', 'mesmo', 'mesma', 'separado', 'separados',
      'separada', 'separadas', 'certinho', 'direito',
    };
    var i = 0;
    while (i < words.length && skip.contains(words[i])) {
      i++;
    }
    if (i >= words.length || acknowledgement.contains(words[i])) return null;
    final first = words[i];
    if (RecipeLanguage.stopwords.contains(first) || RecipeLanguage.re(r'^\d').hasMatch(first)) return null;
    // Verbos ("bora fazer", "peguei comprar") não são itens
    if (RecipeLanguage.re(r'(ar|er|ir)$').hasMatch(first) && first != 'acucar') return null;
    final phrase = <String>[first];
    if (i + 1 < words.length &&
        !RecipeLanguage.stopwords.contains(words[i + 1]) &&
        !acknowledgement.contains(words[i + 1])) {
      phrase.add(words[i + 1]);
    }
    return _spokenForm(original, phrase);
  }

  // Recupera a grafia falada (com acentos) de palavras já normalizadas
  String _spokenForm(_Utterance u, List<String> normalizedWords) {
    final raw = u.raw
        .split(RecipeLanguage.re(r'\s+'))
        .map((w) => w.replaceAll(RecipeLanguage.re(r'^[^A-Za-zÀ-ÿ0-9]+|[^A-Za-zÀ-ÿ0-9]+$'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    final rawNormalized = raw.map(RecipeLanguage.normalize).toList();
    for (var i = 0; i + normalizedWords.length <= raw.length; i++) {
      var same = true;
      for (var k = 0; k < normalizedWords.length; k++) {
        if (rawNormalized[i + k] != normalizedWords[k]) {
          same = false;
          break;
        }
      }
      if (same) return raw.sublist(i, i + normalizedWords.length).join(' ').toLowerCase();
    }
    return normalizedWords.join(' ');
  }

  bool _isShortAcknowledgement(_Utterance u) {
    if (u.has(_lack)) return false;
    if (_isQuestion(u) && !u.has(r'peguei|tenho')) return false;
    // "tenho uma pergunta", "tô com pressa", "tenho que mexer" não falam do ingrediente
    if (u.has(_nonIngredientPossession)) return false;
    if (_unknownAcquiredItem(u, u) != null) return false;
    // "ok/beleza/certo" só confirmam o ingrediente se ele acabou de ser pedido
    final askedToFetch = RecipeLanguage.re(
      r'\b(pegue|pegar|proximo|precisa de|precisar de|voce (ja )?tem|falta|faltam|separe|separar)\b',
    ).hasMatch(RecipeLanguage.normalize(ctx.lastResponse));
    final strong = u.has(
      r'pe(g|gu|qu)ei|separei|separamos|achei|encontrei|comprei|consegui|trouxe|esta aqui|estao aqui|aqui esta|aqui estao|ja esta|ja estao|na mao|ja tenho|tenho (sim|aqui|ja|esse|essa|isso|ele|ela)|tenho$|estou com (ele|ela|esse|essa|isso)|marca|marcar|marque|pode marcar|deixei separad[oa]|ja separei',
    );
    if (u.words.length <= 7) return strong || (askedToFetch && u.has(_acquireWeak));
    // Frase longa que começa confirmando: "tenho sim, tem um tablete na geladeira"
    return u.words.length <= 16 &&
        (u.starts(r'(ja )?(tenho sim|tenho|peguei|pe(g|gu|qu)ei|separei|achei|esta aqui|aqui esta)') ||
            (askedToFetch && u.starts(r'ok|pronto|beleza|certo|feito|sim|isso')));
  }

  int _resolveCurrentIngredient() {
    final current = ctx.currentIngredientIndex;
    if (current >= 0 && current < _ingredientCount && !ctx.ingredientChecked[current]) {
      return current;
    }
    final unchecked = _uncheckedIngredients;
    return unchecked.isEmpty ? -1 : unchecked.first;
  }

  RecipeAssistantIntent _checkIngredients(
    List<int> indexes, {
    List<int> uncheck = const [],
    List<int> missingFocus = const [],
  }) {
    final checkedAfter = List<bool>.from(ctx.ingredientChecked);
    for (final i in indexes) {
      checkedAfter[i] = true;
    }
    for (final i in uncheck) {
      checkedAfter[i] = false;
    }
    final remaining = [
      for (var i = 0; i < _ingredientCount; i++)
        if (!checkedAfter[i]) i,
    ];

    if (remaining.isEmpty) {
      // Durante o preparo, completar a lista não reinicia a receita
      if (_cooking) {
        return _result(
          'check_ingredients',
          '${_ack(indexes.length)}, todos os ingredientes estão marcados. ${_contextHint()}',
          checkIngredients: indexes,
          uncheckIngredients: uncheck,
          confidence: high,
        );
      }
      return _startPrep(prefix: _ack(indexes.length));
    }

    final names = indexes.map((i) => _ingredients[i].name).toList();
    final alreadyChecked = indexes.where((i) => ctx.ingredientChecked[i]).toList();
    final buffer = StringBuffer();
    if (indexes.isEmpty) {
      buffer.write('${_ack(1)}! ');
    } else if (alreadyChecked.length == indexes.length) {
      buffer.write('${_capitalize(RecipeLanguage.joinPt(names))} já ${indexes.length == 1 ? 'estava marcado' : 'estavam marcados'}. ');
    } else {
      buffer.write('${_ack(indexes.length)}, marquei ${RecipeLanguage.joinPt(names)}. ');
    }

    final focus = missingFocus.isNotEmpty ? missingFocus : remaining;
    if (missingFocus.isNotEmpty) {
      buffer.write('Ainda falta: ${RecipeLanguage.joinPt(focus.map((i) => _ingredients[i].spoken).toList())}.');
    } else if (remaining.length == 1) {
      buffer.write('Só falta pegar ${_ingredients[remaining.first].spoken}.');
    } else if (remaining.length <= 3) {
      buffer.write('Faltam: ${RecipeLanguage.joinPt(remaining.map((i) => _ingredients[i].spoken).toList())}.');
    } else {
      buffer.write('Agora pegue ${_ingredients[remaining.first].spoken}. Faltam ${remaining.length} ingredientes.');
    }

    return _result(
      'check_ingredients',
      buffer.toString(),
      checkIngredients: indexes,
      uncheckIngredients: uncheck,
      ingredientIndex: focus.first,
      confidence: high,
    );
  }

  RecipeAssistantIntent _uncheckIngredients(List<int> indexes) {
    final names = indexes.map((i) => _ingredients[i].spoken).toList();
    final text = indexes.length == 1
        ? 'Sem problema, deixei ${_ingredients[indexes.first].name} como pendente. Você vai precisar de ${names.first}.'
        : 'Sem problema, deixei pendentes: ${RecipeLanguage.joinPt(names)}.';
    return _result(
      'uncheck_ingredients',
      text,
      uncheckIngredients: indexes,
      ingredientIndex: indexes.first,
      confidence: high,
    );
  }

  RecipeAssistantIntent _listIngredients() {
    final spoken = _ingredients.map((i) => i.spoken).toList();
    final checkedCount = ctx.ingredientChecked.where((c) => c).length;
    var text = 'Os ingredientes são: ${RecipeLanguage.joinPt(spoken)}.';
    if (checkedCount > 0 && checkedCount < _ingredientCount) {
      text += ' Você já separou $checkedCount.';
    }
    return _result('ingredients', text, confidence: high);
  }

  // Nada falta: antes do preparo oferece começar; durante, só situa o passo
  RecipeAssistantIntent _allIngredientsReady() {
    if (_cooking && _stepCount > 0) {
      return _result(
        'missing_ingredients',
        'Todos os ingredientes já estão separados. Estamos no passo ${_currentStep + 1}.',
        confidence: high,
      );
    }
    return _result(
      'missing_ingredients',
      'Você já separou todos os ingredientes! Quer começar o preparo?',
      pending: 'start_prep',
      confidence: high,
    );
  }

  RecipeAssistantIntent _missingIngredients() {
    final remaining = _uncheckedIngredients;
    if (remaining.isEmpty) {
      return _allIngredientsReady();
    }
    final spoken = remaining.map((i) => _ingredients[i].spoken).toList();
    return _result(
      'missing_ingredients',
      remaining.length == 1
          ? 'Só falta pegar ${spoken.first}.'
          : 'Ainda falta pegar: ${RecipeLanguage.joinPt(spoken)}.',
      ingredientIndex: remaining.first,
      confidence: high,
    );
  }

  // Próximo a pegar: o atual, se ainda não foi pego; ou o seguinte ao item citado
  RecipeAssistantIntent _nextIngredient({int? after}) {
    final remaining = _uncheckedIngredients;
    if (remaining.isEmpty) {
      return _allIngredientsReady();
    }
    final int next;
    if (after != null) {
      next = remaining.firstWhere((i) => i > after, orElse: () => remaining.first);
    } else {
      final current = ctx.currentIngredientIndex;
      next = remaining.firstWhere((i) => i >= current, orElse: () => remaining.first);
    }
    return _result(
      'next_ingredient',
      'Próximo ingrediente: ${_ingredients[next].spoken}.',
      ingredientIndex: next,
      confidence: high,
    );
  }

  RecipeAssistantIntent _quantityAnswer(List<_Mention> mentions) {
    String describe(ParsedIngredient ing) {
      if (ing.hasQuantity) return ing.spoken;
      if (ing.toTaste) return '${ing.name} a gosto';
      return '${ing.name}, sem quantidade definida';
    }

    final String text;
    if (mentions.length == 1) {
      final ing = _ingredients[mentions.first.index];
      if (ing.hasQuantity) {
        text = 'Vai ${ing.spoken}.';
      } else if (ing.toTaste) {
        text = '${_capitalize(ing.name)} vai a gosto.';
      } else {
        text = 'A receita não diz a quantidade exata de ${ing.name}.';
      }
    } else {
      text = 'Vai ${RecipeLanguage.joinPt(mentions.map((m) => describe(_ingredients[m.index])).toList())}.';
    }
    return _result(
      'ingredient_info',
      text,
      ingredientIndex: mentions.first.index,
      confidence: high,
    );
  }

  // Passos que citam o ingrediente: primeiro pelo nome principal; se não
  // aparecer, pelos outros nomes ("coxa e sobrecoxa de frango" -> "frango")
  List<int> _stepsUsingIngredient(int index) {
    final ing = _ingredients[index];
    final keys = ing.keyWords.where((k) => !ing.isWeak(k)).toList();
    for (final key in keys) {
      final result = <int>[
        for (var s = 0; s < _stepCount; s++)
          if (_stepWords[s].any((w) => RecipeLanguage.wordsMatch(w, key))) s,
      ];
      if (result.isNotEmpty) return result;
    }
    return const [];
  }

  RecipeAssistantIntent _whereUsedAnswer(List<_Mention> mentions) {
    final sentences = <String>[];
    for (final m in mentions) {
      final ing = _ingredients[m.index];
      final steps = _stepsUsingIngredient(m.index);
      if (steps.isEmpty) {
        sentences.add('Não encontrei em qual passo ${ing.name} é usado; a receita pede ${ing.spoken}.');
      } else if (steps.length == 1) {
        sentences.add('${_capitalize(ing.name)} entra no passo ${steps.first + 1}: ${_stepText(steps.first)}.');
      } else {
        sentences.add(
          '${_capitalize(ing.name)} aparece nos passos ${RecipeLanguage.joinPt(steps.map((s) => '${s + 1}').toList())}. '
          'Primeiro no passo ${steps.first + 1}: ${_stepText(steps.first)}.',
        );
      }
    }
    return _result('ingredient_info', sentences.join(' '), confidence: high);
  }

  // Variante diferente do ingrediente ("leite condensado" quando a receita
  // pede "leite", "batata doce" quando pede "batata")
  String? _variantPhrase(_Mention m, _Utterance u) {
    if (m.positions.isEmpty) return null;
    final ing = _ingredients[m.index];
    final start = m.positions.reduce((a, b) => a < b ? a : b);
    final phrase = <String>[];
    for (var p = start; p < u.words.length && phrase.length < 3; p++) {
      final w = u.words[p];
      if (RecipeLanguage.stopwords.contains(w) || RecipeLanguage.re(r'^\d').hasMatch(w)) break;
      // pula conectores dentro do nome ("creme de leite")
      phrase.add(w);
    }
    final unexplained = phrase
        .where((w) => !ing.keyWords.any((k) => RecipeLanguage.wordsMatch(w, k)) && !ing.isWeak(w))
        .toList();
    return unexplained.isEmpty ? null : _spokenForm(u, phrase);
  }

  RecipeAssistantIntent _presenceAnswer(List<_Mention> mentions, [_Utterance? u]) {
    if (u != null && mentions.length == 1) {
      final variant = _variantPhrase(mentions.first, u);
      if (variant != null) {
        final ing = _ingredients[mentions.first.index];
        return _result(
          'ingredient_info',
          'Não, a receita não leva $variant. Ela pede ${ing.spoken}.',
          confidence: medium,
        );
      }
    }
    final parts = <String>[];
    for (final m in mentions) {
      final ing = _ingredients[m.index];
      final steps = _stepsUsingIngredient(m.index);
      final where = steps.isEmpty ? '' : ', usado no passo ${steps.first + 1}';
      parts.add('${ing.spoken}$where');
    }
    final prefix = mentions.every((m) => m.headMatched) ? 'Sim, a receita leva' : 'A receita leva';
    return _result(
      'ingredient_info',
      '$prefix ${RecipeLanguage.joinPt(parts)}.',
      confidence: mentions.every((m) => m.headMatched) ? high : medium,
    );
  }

  RecipeAssistantIntent? _absentIngredientAnswer(_Utterance u) {
    // Procura o "objeto" da pergunta: "leva manteiga?", "tem coco nessa receita?"
    const notFood = {
      'passo', 'tempo', 'forno', 'fogo', 'forma', 'receita', 'que', 'mais',
      'quanto', 'minutos', 'graus', 'temperatura', 'certeza', 'como', 'jeito',
      'problema', 'duvida', 'pressa', 'mesmo', 'fazer', 'comecar', 'preparo',
      'bolo', 'massa', 'cobertura', 'agora', 'depois', 'hoje', 'tigela',
      'liquidificador', 'batedeira', 'ajuda', 'algo', 'alguma', 'cuidado',
      'demorar', 'ficar', 'precisar', 'colocar', 'terminar', 'acabar', 'assar',
      'bater', 'misturar', 'mexer', 'levar', 'chover', 'acontecer', 'dar',
      'muito', 'pouco', 'falar', 'perguntar', 'saber', 'usar', 'panela', 'prato',
    };
    const presenceVerbs = {
      'leva', 'levam', 'tem', 'vai', 'precisa', 'preciso', 'usa', 'usar',
      'entra', 'inclui', 'contem', 'colocar', 'coloca',
    };
    const foodEndingInVerbSuffix = {'acucar', 'manjar', 'caviar', 'licor'};
    bool looksLikeFood(String word) {
      if (RecipeLanguage.isUnitWord(word)) return false;
      if (RecipeLanguage.re(r'(ar|er|ir|ando|endo|indo|inho|inha)$').hasMatch(word) &&
          !foodEndingInVerbSuffix.contains(word)) {
        return false;
      }
      return true;
    }
    final titleWords = RecipeLanguage.contentWords(ctx.title);
    final aboutRecipe = u.has(r'receita|nessa|nesse|neste|nesta|esse|essa|no bolo|na massa|no prato') ||
        u.words.any((w) => titleWords.any((t) => RecipeLanguage.wordsMatch(w, t)));
    const skip = {
      'o', 'a', 'os', 'as', 'um', 'uma', 'de', 'do', 'da', 'algum', 'alguma',
      'que', 'usar', 'colocar', 'ter', 'por', 'mesmo', 'tambem',
    };
    List<String>? candidate;
    final w = u.words;
    for (var i = 0; i < w.length && candidate == null; i++) {
      final isVerb = presenceVerbs.contains(w[i]) || (w[i] == 'com' && i > 0 && w[i - 1] == 'e');
      if (!isVerb) continue;
      // Pergunta de presença vem no começo da frase ou cita a receita
      if (i > 8 && !aboutRecipe) continue;
      var j = i + 1;
      while (j < w.length && skip.contains(w[j])) {
        j++;
      }
      final found = <String>[];
      while (j < w.length && found.length < 3) {
        final word = w[j];
        // "extrato de tomate": mantém o "de" dentro do nome
        if (word == 'de' && found.isNotEmpty && j + 1 < w.length &&
            !RecipeLanguage.stopwords.contains(w[j + 1]) && !notFood.contains(w[j + 1])) {
          found.add(word);
          j++;
          continue;
        }
        if (RecipeLanguage.stopwords.contains(word) || notFood.contains(word) || word.length <= 2) break;
        if (found.isEmpty && !looksLikeFood(word)) break;
        found.add(word);
        j++;
      }
      if (found.isNotEmpty && found.last == 'de') found.removeLast();
      if (found.isNotEmpty) candidate = found;
    }
    if (candidate == null) return null;
    final word = candidate.first;

    final steps = <int>[
      for (var s = 0; s < _stepCount; s++)
        if (_stepWords[s].any((w) => RecipeLanguage.wordsMatch(w, word))) s,
    ];
    final display = _spokenForm(u, candidate);
    if (steps.isNotEmpty) {
      return _result(
        'ingredient_info',
        '${_capitalize(display)} não está na lista de ingredientes, mas aparece no passo ${steps.first + 1}: ${_stepText(steps.first)}.',
        confidence: high,
      );
    }
    return _result(
      'ingredient_info',
      'Não, essa receita não leva $display. Os ingredientes são: '
          '${RecipeLanguage.joinPt(_ingredients.map((i) => i.name).toList())}.',
      confidence: medium,
    );
  }

  RecipeAssistantIntent _substitutionAnswer(List<_Mention> mentions) {
    final ing = _ingredients[mentions.first.index];
    return _result(
      'ingredient_info',
      'A receita pede ${ing.spoken}. Trocar ingredientes pode mudar o resultado, '
          'então o mais seguro é seguir a receita como está.',
      confidence: low,
    );
  }

  // ---------------------------------------------------------------------------
  // Início do preparo
  // ---------------------------------------------------------------------------

  RecipeAssistantIntent? _startPrepIntent(_Utterance u) {
    if (u.has(r'(nao|ainda nao) (quero|vou|posso|da para) (comecar|ir)|antes de comecar|como comecar|quando comecar|posso comecar\b.*\?')) {
      return null;
    }
    // Perguntas e planos ("dá pra fazer na air fryer?", "vou fazer amanhã",
    // "quero fazer pela metade") não são pedido para começar agora
    final simpleCanStart = RecipeLanguage.re(
      r'^(ja )?(posso|podemos|da para|ja da para) (comecar|ir para o preparo|comecar o preparo)( agora| ja| entao)?$',
    ).hasMatch(u.text);
    if (simpleCanStart && _gathering) return _startPrep();
    if (u.starts(r'posso|da para|sera|como|quando|e se|pode ser|tem como|consigo|seria') ||
        u.has(
          r'(comecar|iniciar|cozinhar|preparar|fazer) (na|no|nos|nas|sem|com|em|pela|pelo|amanha|depois|de vespera|em dobro|metade|antes|mais tarde|outro dia|hoje a noite|semana)\b|amanha|de vespera|mais tarde|outro dia|semana que vem|em dobro|pela metade|metade da receita',
        )) {
      return null;
    }
    final wantsStart = u.has(
      r'(vamos|bora|pode|podemos|quero|vou|ja posso|posso|hora de|partiu|vamos la|bora la|ja da para|da para) (comecar|iniciar|cozinhar|preparar|fazer|o preparo|para o preparo|ir para o preparo|para os passos|para o modo de preparo|a receita|o bolo|ir para os passos)|comecar o preparo|comecar a (receita|fazer|preparar|cozinhar)|iniciar o preparo|ir para o (preparo|modo de preparo)|para o modo de preparo|mao na massa|partiu preparo|bora cozinhar|vamos cozinhar|pode comecar|vamos comecar|bora comecar|pode iniciar|comeca o preparo|comecar logo|vamos para o preparo|bora para o preparo|vamos aos passos|pode ir para o preparo|ja podemos comecar|ja vamos comecar',
    );
    final bareModoPreparo = RecipeLanguage.re(r'^(o |e o |vamos )?modo de preparo$').hasMatch(u.text);
    final bareStart = RecipeLanguage.re(r'^(vamos|bora|partiu|comecar|comeca|vamos la|bora la)$').hasMatch(u.text);
    // "vou fazer essa sopa", "quero fazer a vitamina agora": intenção de cozinhar.
    // Com ingredientes ainda pendentes, mostra o que falta e oferece começar.
    final onlyIntent = u.has(r'(quero|vou|podemos|pretendo|ia) (fazer|preparar|cozinhar)') &&
        !u.has(r'comecar|comeca|iniciar|mao na massa|partiu|preparo|passos|vamos|bora');
    if (wantsStart && onlyIntent && _gathering && _uncheckedIngredients.isNotEmpty) {
      final remaining = _uncheckedIngredients;
      final allMissing = remaining.length == _ingredientCount;
      return _result(
        'ingredients',
        '${allMissing ? 'Para fazer ${ctx.title} você vai precisar de' : 'Ainda falta pegar'}: '
            '${RecipeLanguage.joinPt(remaining.map((i) => _ingredients[i].spoken).toList())}. '
            'Quer começar o preparo assim mesmo?',
        pending: 'start_prep',
        confidence: high,
      );
    }
    if (wantsStart || bareModoPreparo || (bareStart && _gathering)) {
      if (_cooking && _currentStep > 0 && !u.has(r'de novo|do zero|do comeco|do inicio')) {
        return _goToStep(_currentStep, 'current_step');
      }
      return _startPrep();
    }
    return null;
  }

  RecipeAssistantIntent _startPrep({String? prefix}) {
    final all = [for (var i = 0; i < _ingredientCount; i++) if (!ctx.ingredientChecked[i]) i];
    final intro = prefix == null
        ? (_ingredientCount == 0
            ? 'Vamos começar.'
            : 'Perfeito! Todos os ingredientes estão prontos. Vamos começar.')
        : '$prefix! Todos os ingredientes estão prontos. Vamos começar.';
    if (_stepCount == 0) {
      return _result(
        'start_prep',
        '${intro.replaceFirst(' Vamos começar.', '')} Ainda não há passos de preparo cadastrados.',
        checkIngredients: all,
        mode: RecipeAssistantModes.passos,
        step: 0,
        confidence: high,
      );
    }
    return _result(
      'start_prep',
      '$intro ${_stepSentence(0)}',
      checkIngredients: all,
      mode: RecipeAssistantModes.passos,
      step: 0,
      confidence: high,
    );
  }

  // ---------------------------------------------------------------------------
  // Modo de preparo completo
  // ---------------------------------------------------------------------------

  RecipeAssistantIntent? _readAllIntent(_Utterance u) {
    if (_stepCount == 0) return null;
    // "como faz essa panqueca?" usando o nome do prato
    final howMake = RecipeLanguage.re(
      r'\bcomo (?:se )?(?:faz|faco|fazer|prepara|preparo|preparar) (?:a |o |essa |esse |este |esta |uma |um )?([a-z]+)',
    ).firstMatch(u.text);
    if (howMake != null) {
      final dish = howMake.group(1)!;
      final titleWords = RecipeLanguage.contentWords(ctx.title);
      if (titleWords.any((w) => RecipeLanguage.wordsMatch(dish, w))) return _readAllSteps();
    }
    if (u.has(
      r'(receita|modo de preparo|modo de fazer|preparo|passo a passo|passos|etapas) (toda|todo|inteira|inteiro|completa|completo|de uma vez)|todos os passos?|todas as etapas?|(os )?(passos?|etapas?) (tudo|todos|todas)|tudo de uma vez|do (comeco|inicio) (ao|ate o) fim|(le|leia|ler|fala|fale|diz|diga|conta|conte|me passa|passa) (a receita|o modo de (preparo|fazer)|todo o preparo|o preparo todo|a receita toda|todos os passos?|tudo)|como (se )?faz (a receita|o bolo|esse bolo|essa receita|esse prato|isso tudo)|como e o (modo de )?preparo|qual e o modo de preparo|quais sao os passos|me (fala|diz|diga|conta) (o modo de preparo|a receita|como faz)',
    )) {
      return _readAllSteps();
    }
    return null;
  }

  RecipeAssistantIntent _readAllSteps() {
    final steps = [for (var i = 0; i < _stepCount; i++) _stepSentence(i)];
    return _result(
      'read_all_steps',
      'O modo de preparo tem $_stepCount ${_stepCount == 1 ? 'passo' : 'passos'}. ${steps.join(' ')}',
      confidence: high,
    );
  }

  // ---------------------------------------------------------------------------
  // Informações gerais: tempo, temperatura, progresso, nome
  // ---------------------------------------------------------------------------

  bool _isTimeQuestion(_Utterance u) {
    if (u.has(r'previsao|chover|chuva|clima|tempo (esta|vai|hoje|la fora)|que horas sao')) {
      return false;
    }
    return u.has(
      r'quanto tempo|por quanto tempo|tempo de|tempo no|tempo que|tempo para|quantos minutos?|quantas horas?|minutos?|horas?|demora|demorar|demorado|leva quanto|ate quando|cronometro|timer|como (eu )?sei (se|que) (esta|ficou|ta) pronto|quando (esta|fica|vai ficar|ta) pronto|como saber se (esta|ficou) pronto|ponto (certo|do bolo|da massa)|tempo',
    );
  }

  bool _isTemperatureQuestion(_Utterance u) {
    if (u.has(
      r'temperatura|graus?|qual (o )?fogo|que fogo|intensidade|potencia|em quantos graus|(alto|baixo|medio|forte|fraco|brando) ou (alto|baixo|medio|forte|fraco|brando)',
    )) {
      return true;
    }
    // "quente", "fogo baixo", "forno" só contam quando há pergunta
    final asks = _isQuestion(u) || u.has(r'qual|quanto|quantos|que|como|sera');
    return asks &&
        !_isTimeQuestion(u) &&
        u.has(r'quente|aquecer|preaquecer|pre aquecer|fogo|chama|forno');
  }

  RecipeAssistantIntent? _recipeInfoIntent(_Utterance u) {
    if (_isTimeQuestion(u)) return _timeAnswer(u);
    if (_isTemperatureQuestion(u)) return _temperatureAnswer(u);

    final countsSteps = u.has(r'quant(os|as) (passos?|etapas?|partes?)');
    final remainingWords = u.has(
      r'falta|faltam|faltando|resta|restam|ainda tem|pela frente|ate acabar|ate terminar|ja fiz|ja foram|ja terminei|fiz quant\w*|terminei quant\w*|ja conclui',
    );
    if (countsSteps && !remainingWords) {
      return _result(
        'recipe_info',
        'A receita tem $_stepCount ${_stepCount == 1 ? 'passo' : 'passos'}.',
        confidence: high,
      );
    }
    if (countsSteps ||
        u.has(
          r'(quanto|quantos|quantas) (ainda )?(falta|faltam|resta|restam)|falta muito|ainda falta muito|esta (acabando|terminando|no fim|no final)|ja (esta|estamos) (acabando|no final|terminando)|falta pouco|progresso|quantos (passos )?(ja )?(fiz|foram|terminei)|(ja )?fiz quantos|em que parte (eu )?(estou|estamos)|quanto (eu )?ja fiz|pela frente',
        ) ||
        (u.has(r'passos?|etapas?') && u.has(r'falta|faltam|resta|restam|muito ainda|ainda tem muito')) ||
        (_cooking && RecipeLanguage.re(r'^(e )?(o que|que|quanto) (ainda )?falta$').hasMatch(u.text))) {
      return _progressAnswer();
    }
    if (u.has(
      r'(qual|que) (e )?(o )?(nome d(a|essa|esta) )?(receita|prato)( e essa| e esse| e essa aqui| estamos fazendo| eu estou fazendo| a gente esta fazendo)?$|nome da receita|nome dessa receita|o que (a gente|nos|eu) (esta|estamos|estou) (fazendo|cozinhando|preparando)|que (bolo|prato|receita) e (esse|essa)|(qual|que) (e a |essa |esta )?receita',
    )) {
      return _result('recipe_info', 'Estamos fazendo a receita ${ctx.title}.', confidence: high);
    }
    return null;
  }

  static final RegExp _timePattern = RecipeLanguage.re(
    r'\b(\d+(?:\.\d+)?|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta|quarenta|cinquenta|sessenta|meia)\s*(?:a\s*(\d+)\s*)?(segundos?|minutos?|min|horas?|h)\b',
  );

  static const Map<String, int> _bigNumbers = {
    'quinze': 15, 'vinte': 20, 'trinta': 30, 'quarenta': 40, 'cinquenta': 50,
    'sessenta': 60,
  };

  List<_TimeMention> _timeMentions() {
    final result = <_TimeMention>[];
    for (var s = 0; s < _stepCount; s++) {
      final text = RecipeLanguage.normalize(ctx.instructions[s]);
      for (final m in _timePattern.allMatches(text)) {
        final token = m.group(1)!;
        final number = token == 'meia'
            ? 0.5
            : (double.tryParse(token) ??
                (RecipeLanguage.numberWords[token] ?? _bigNumbers[token] ?? 0)
                    .toDouble());
        final upper = m.group(2) == null ? null : double.tryParse(m.group(2)!);
        final unit = m.group(3)!;
        final factor = unit.startsWith('h') ? 60.0 : (unit.startsWith('seg') ? 1 / 60 : 1.0);
        result.add(_TimeMention(s, (upper ?? number) * factor, m.group(0)!));
      }
    }
    return result;
  }

  int? _bestMatchingStep(_Utterance u, {bool Function(int)? where}) {
    var best = 0;
    int? bestIndex;
    final words = u.content.where((w) => w.length >= 3).toList();
    for (var s = 0; s < _stepCount; s++) {
      if (where != null && !where(s)) continue;
      var score = 0;
      for (final w in words) {
        if (_stepWords[s].any((sw) => RecipeLanguage.wordsMatch(w, sw))) score++;
      }
      if (score > best) {
        best = score;
        bestIndex = s;
      }
    }
    return bestIndex;
  }

  RecipeAssistantIntent _timeAnswer(_Utterance u, {int? onlyStep}) {
    final times = _timeMentions();
    final doneness = [
      for (var s = 0; s < _stepCount; s++)
        if (RecipeLanguage.re(r'\bate (que|dourar|ferver|engrossar|ficar|desgrudar|crescer|soltar|o ponto|perder)|palito|ponto de|quando (a|o|as|os) \w+ (soltar|ferver|dourar|crescer|engrossar|borbulhar|estiver)')
            .hasMatch(RecipeLanguage.normalize(ctx.instructions[s])))
          s,
    ];
    // O passo atual vem primeiro; depois o que mais combina com a pergunta
    if (doneness.contains(_currentStep) && _cooking) {
      doneness
        ..remove(_currentStep)
        ..insert(0, _currentStep);
    } else {
      final best = _bestMatchingStep(u, where: doneness.contains);
      if (best != null) {
        doneness
          ..remove(best)
          ..insert(0, best);
      }
    }

    if (onlyStep != null) {
      final inStep = times.where((t) => t.step == onlyStep).toList();
      if (inStep.isEmpty) {
        return _result(
          'recipe_info',
          'O passo ${onlyStep + 1} não indica um tempo. Ele diz: ${_stepText(onlyStep)}.',
          confidence: high,
        );
      }
      return _result('recipe_info', 'No passo ${onlyStep + 1}: ${_stepText(onlyStep)}.', confidence: high);
    }

    if (u.has(r'como (eu )?sei|quando (esta|fica|vai ficar|ta) pronto|como saber|ponto|hora de (virar|tirar|desligar|mexer)')) {
      if (doneness.isNotEmpty) {
        return _result(
          'recipe_info',
          'A receita diz no passo ${doneness.first + 1}: ${_stepText(doneness.first)}.',
          confidence: high,
        );
      }
    }

    if (times.isEmpty) {
      final hint = doneness.isEmpty ? '' : ' No passo ${doneness.first + 1}, a receita diz: ${_stepText(doneness.first)}.';
      return _result(
        'recipe_info',
        'A receita não informa um tempo específico.$hint',
        confidence: high,
      );
    }

    if (u.has(r'falta|faltam|resta|restam')) {
      final remaining = times.where((t) => t.step >= _currentStep).toList();
      if (remaining.isEmpty) return _progressAnswer();
      final total = remaining.fold<double>(0, (sum, t) => sum + t.minutes);
      return _result(
        'recipe_info',
        'Pelos tempos indicados nos próximos passos, ainda faltam cerca de ${_formatMinutes(total)}, '
            'fora o tempo de preparo de cada passo.',
        confidence: high,
      );
    }

    if (u.has(r'total|toda|todo|inteira|inteiro|tudo|ao todo|receita leva|demora a receita|o bolo demora|fica pronto')) {
      if (times.length == 1) {
        return _result(
          'recipe_info',
          'O único tempo indicado é ${times.first.text}, no passo ${times.first.step + 1}: ${_stepText(times.first.step)}.',
          confidence: high,
        );
      }
      final total = times.fold<double>(0, (sum, t) => sum + t.minutes);
      final parts = times.map((t) => '${t.text} no passo ${t.step + 1}').toList();
      return _result(
        'recipe_info',
        'Somando os tempos indicados, são cerca de ${_formatMinutes(total)}: ${RecipeLanguage.joinPt(parts)}, '
            'mais o tempo de preparo.',
        confidence: high,
      );
    }

    // Pergunta ligada ao forno ou a algum trecho específico da receita
    final ovenSteps = times
        .where((t) => RecipeLanguage.re(r'\b(ass[aeo]\w*|forno)\b').hasMatch(RecipeLanguage.normalize(ctx.instructions[t.step])))
        .toList();
    final currentIsOven = RecipeLanguage.re(r'\b(ass[aeo]\w*|forno|preaquec\w*)\b').hasMatch(RecipeLanguage.normalize(ctx.instructions[_currentStep]));
    if (u.has(r'forno|assar|asse|assando|assa') && ovenSteps.isNotEmpty &&
        !(currentIsOven && times.every((t) => t.step != _currentStep) && u.has(r'preaquec\w*|aquecendo|esquentar'))) {
      final t = ovenSteps.first;
      return _result('recipe_info', 'No passo ${t.step + 1}: ${_stepText(t.step)}.', confidence: high);
    }
    final specific = _bestMatchingStep(u, where: (s) => times.any((t) => t.step == s));
    if (specific != null) {
      return _result('recipe_info', 'No passo ${specific + 1}: ${_stepText(specific)}.', confidence: high);
    }
    final inCurrent = times.where((t) => t.step == _currentStep).toList();
    if (_cooking && inCurrent.isNotEmpty) {
      return _result(
        'recipe_info',
        'Neste passo são ${inCurrent.first.text}: ${_stepText(_currentStep)}.',
        confidence: high,
      );
    }
    // Cozinhando num passo sem tempo: não atribui o tempo de outro passo
    if (_cooking) {
      final others = times.map((t) => '${t.text} no passo ${t.step + 1}').toList();
      return _result(
        'recipe_info',
        'O passo ${_currentStep + 1} não indica um tempo: ${_stepText(_currentStep)}. '
            'Os tempos da receita são ${RecipeLanguage.joinPt(others)}.',
        confidence: medium,
      );
    }
    if (times.length == 1) {
      return _result(
        'recipe_info',
        'No passo ${times.first.step + 1}: ${_stepText(times.first.step)}.',
        confidence: high,
      );
    }
    final parts = times.map((t) => '${t.text} no passo ${t.step + 1}').toList();
    return _result(
      'recipe_info',
      'A receita indica ${RecipeLanguage.joinPt(parts)}.',
      confidence: high,
    );
  }

  String _formatMinutes(double minutes) {
    final total = minutes.round();
    if (total < 60) return '$total minutos';
    final h = total ~/ 60;
    final m = total % 60;
    final hours = h == 1 ? '1 hora' : '$h horas';
    return m == 0 ? hours : '$hours e $m minutos';
  }

  RecipeAssistantIntent _temperatureAnswer(_Utterance u, {int? onlyStep}) {
    final degrees = <int, String>{};
    final heat = <int, String>{};
    for (var s = 0; s < _stepCount; s++) {
      if (onlyStep != null && s != onlyStep) continue;
      final text = RecipeLanguage.normalize(ctx.instructions[s]);
      final d = RecipeLanguage.re(r'\b(\d{2,3})\s*graus\b').firstMatch(text);
      if (d != null) degrees[s] = '${d.group(1)} graus';
      final f = RecipeLanguage.re(r'\b(fogo|chama|forno) (baixo|baixa|medio|media|alto|alta|brando|branda)\b').firstMatch(text);
      if (f != null) heat[s] = '${f.group(1)} ${_accent(f.group(2)!)}';
    }
    final asksHeat = u.has(r'fogo|chama|fogao|panela|cobertura|derret\w*');
    final parts = <String>[];
    if (!asksHeat || heat.isEmpty) {
      degrees.forEach((s, v) => parts.add('O forno deve estar a $v, no passo ${s + 1}: ${_stepText(s)}.'));
    }
    if (asksHeat || degrees.isEmpty || parts.isEmpty) {
      heat.forEach((s, v) => parts.add('Use $v no passo ${s + 1}: ${_stepText(s)}.'));
    }
    if (parts.isEmpty) {
      return _result(
        'recipe_info',
        onlyStep == null
            ? 'A receita não informa a temperatura.'
            : 'O passo ${onlyStep + 1} não informa a temperatura. Ele diz: ${_stepText(onlyStep)}.',
        confidence: high,
      );
    }
    return _result('recipe_info', parts.join(' '), confidence: high);
  }

  String _accent(String word) {
    const map = {'medio': 'médio', 'media': 'média'};
    return map[word] ?? word;
  }

  RecipeAssistantIntent _progressAnswer() {
    if (_stepCount == 0) {
      return _result('recipe_info', 'Essa receita ainda não tem passos cadastrados.', confidence: high);
    }
    if (_gathering && _uncheckedIngredients.isNotEmpty) {
      final remaining = _uncheckedIngredients.length;
      return _result(
        'recipe_info',
        'Ainda estamos separando os ingredientes: faltam $remaining. Depois vêm os $_stepCount passos do preparo.',
        confidence: high,
      );
    }
    final current = _currentStep;
    final checkedCount = ctx.instructionChecked.where((c) => c).length;
    final done = checkedCount > 0 ? checkedCount : current;
    final remaining = _stepCount - current;
    final doneText = done == 0
        ? 'ainda não concluiu nenhum'
        : (done == 1 ? 'já concluiu 1' : 'já concluiu $done');
    final text = remaining <= 1
        ? 'Você está no último passo, o $_stepCount de $_stepCount, e $doneText. Falta só este!'
        : 'Você está no passo ${current + 1} de $_stepCount: $doneText e faltam $remaining, contando este.';
    return _result('recipe_info', text, confidence: high);
  }

  // ---------------------------------------------------------------------------
  // Navegação pelos passos
  // ---------------------------------------------------------------------------

  RecipeAssistantIntent? _clauseNavigationIntent(_Utterance u) {
    if (_stepCount == 0) return null;
    if (_isQuantityQuestion(u) || _isTimeQuestion(u) || _isTemperatureQuestion(u)) return null;
    // Separando ingredientes, "depois do leite, qual eu pego?" fala de ingrediente
    if (_gathering && u.has(r'pego|pegar|busco|buscar|separo|separar|ingredientes?')) return null;
    if (!u.has(r'o que|qual|faco|fazer|vem|e depois|proximo|proxima|seguinte|era') &&
        !u.starts(r'depois|e depois|antes|e antes')) {
      return null;
    }
    final after = RecipeLanguage.re(
      r'\b(?:depois (?:de|que|do|da|desse|dessa|deste|desta|daquele|daquela)|quando (?:eu )?(?:acabar|terminar|tiver terminado|tiver acabado|fizer|terminei|acabei)(?: de)?|assim que (?:eu )?(?:acabar|terminar)(?: de)?) (.+)$',
    ).firstMatch(u.text);
    final before = RecipeLanguage.re(r'\bantes (?:de|do|da) (.+)$').firstMatch(u.text);
    final match = after ?? before;
    if (match == null) return null;
    final clause = _Utterance.parse(match.group(1)!, alreadyNormalized: true);
    if (clause.content.isEmpty) return null;
    final step = _bestMatchingStep(clause);
    if (step == null) return null;
    if (after != null) {
      return _goToStep(step + 1, 'next_step');
    }
    return _goToStep(step - 1, 'previous_step');
  }

  static const Set<String> _notCompletionVerbs = {
    'peguei', 'comecei', 'voltei', 'achei', 'esqueci', 'sei', 'vi', 'ouvi',
    'entendi', 'perdi', 'fui', 'tirei', 'cheguei', 'liguei', 'parei',
    'errei', 'pensei', 'falei', 'perguntei', 'escutei', 'aqui', 'ai', 'ali',
  };

  bool _saysStepDone(_Utterance u, {int? step}) {
    if (u.has(r'quant\w*')) return false; // "já fiz quantos passos?" é pergunta
    if (u.has(r'(nao|ainda nao|nem|nunca) (\w+ )?(terminei|acabei|fiz|conclui|finalizei|bati|misturei|coloquei|consegui|deu|fizemos|vi|soube|entendi|usei|preparei)')) {
      return false;
    }
    if (u.has(r'o que e|o que significa|o que quer dizer|e o que')) return false;
    // "o palito não saiu limpo", "não ficou pronto", "tá quase pronto"
    if (u.has(
      r'(nao|nem|nunca|quase|ainda nao)( \w+){0,3} (pronto|pronta|prontos|prontas|prontinho|feito|feita|terminei|acabei|fiz|saiu|ficou|esta|ta|liguei|conclui|assou|dourou|deu|coloquei|bati|misturei)',
    )) {
      return false;
    }
    if (u.has(r'quase (pronto|pronta|la|terminando|acabando|no ponto)|falta (muito|pouco|um pouco|quanto)|falta para ficar')) {
      return false;
    }
    if (u.has(r'comecei|vou|quero|como|quando|quanto|preciso')) {
      if (!u.has(r'ja (fiz|terminei|acabei|bati|misturei|coloquei)|terminei|acabei')) return false;
    }
    if (u.has(
      r'terminei|termine|terminamos|terminado|terminada|acabei|acabamos|feito|feita|ja fiz|fiz|pronto|pronta|prontinho|conclui|concluido|concluida|finalizei|finalizado|ja foi|consegui|deu certo|liguei o forno|desliguei|tirei (\w+ ){0,3}do forno|palito saiu limpo|saiu limpo|esta no forno|ja esta no forno|foi para o forno|ok feito|esta feito|ja esta feito|fechou|passo feito|etapa feita|esse ja foi|esse passo ja|essa etapa ja',
    )) {
      return true;
    }
    // Verbo do próprio passo no passado ou particípio:
    // "já bati tudo", "misturei", "a forma tá untada", "assou"
    if (_stepCount == 0) return false;
    final target = _clampStep(step ?? _currentStep);
    for (final w in u.words) {
      if (w.length < 4 || _notCompletionVerbs.contains(w)) continue;
      final pastForm = RecipeLanguage.re(r'(ei|ou|eu|iu|ado|ada|ados|adas|ido|ida|idos|idas)$').hasMatch(w) ||
          (w.endsWith('i') && !w.endsWith('ai'));
      if (pastForm && _stepWords[target].any((sw) => RecipeLanguage.sameVerb(w, sw))) return true;
      // Verbo parecido com o do passo ("joguei tudo na panela" ~ "junte")
      if (pastForm || w == 'pus' || w == 'botei') {
        final family = _verbFamily(w);
        if (family != null && _stepWords[target].any((sw) => _verbFamily(sw) == family)) return true;
      }
    }
    if (u.has(r'\bpus\b') && _stepWords[target].any((sw) => _verbFamily(sw) == 'juntar')) return true;
    return false;
  }

  // Grupos de verbos de cozinha que descrevem a mesma ação
  static const Map<String, List<String>> _verbFamilies = {
    'juntar': ['junt', 'coloc', 'adicion', 'acrescent', 'despej', 'jog', 'bot', 'ponh', 'incorpor', 'pus'],
    'misturar': ['mistur', 'mex', 'bat', 'incorpor', 'mexid'],
    'cortar': ['cort', 'pic', 'fati', 'pic', 'rale', 'ral'],
    'cozinhar': ['cozinh', 'ferv', 'refog', 'dour', 'frit', 'ass', 'aquec'],
  };

  String? _verbFamily(String word) {
    final r = RecipeLanguage.root(word);
    for (final entry in _verbFamilies.entries) {
      if (entry.value.any((stem) => r == stem || (r.length > stem.length && r.startsWith(stem) && stem.length >= 4))) {
        return entry.key;
      }
    }
    return null;
  }

  bool _wantsUncheckStep(_Utterance u) {
    return u.has(
      r'desmarca\w*|desmarque|tira (a |o )?(marca|marcacao|check)|tira (esse|essa|isso|ele|ela) (da lista|dos feitos|do feito)|(da|dos) (lista de )?feitos?|(nao|ainda nao|nem) (terminei|acabei|fiz|conclui|finalizei|esta pronto|esta pronta|esta feito|deu|consegui)|ainda (esta|ta) (cru|crua|mole|liquido|liquida|congelad[oa])|(ficou|esta|ta) (tudo )?(cru|crua) (por dentro|no meio)|ainda estou (fazendo|nesse|nele)|ainda to fazendo|marcou errado|marquei errado|marquei (que|sem querer)|nao era para marcar|volta a marcacao',
    );
  }

  RecipeAssistantIntent? _completeStepIntent(_Utterance u) {
    if (_stepCount == 0) return null;
    final negatedVerb = _cooking && _negatedStepVerb(u);
    if ((_wantsUncheckStep(u) || negatedVerb) && (_cooking || u.has(r'passo|etapa'))) {
      return _uncheckStep(_stepNotActuallyDone(u));
    }
    if (_gathering) return null;
    if (_isQuestion(u) && !u.has(r'terminei|acabei|ja fiz')) return null;
    if (!_saysStepDone(u)) return null;
    if (u.has(r'(terminei|acabei|fiz|conclui|finalizei) (todos os passos|todas as etapas|a receita toda|a receita inteira)')) {
      return _finishAllSteps();
    }
    return _completeStep(_currentStep);
  }

  RecipeAssistantIntent _completeStep(int index) {
    final step = _clampStep(index);
    if (step >= _stepCount - 1) {
      return _result(
        'complete_step',
        'Perfeito! Você concluiu o último passo. A receita ${ctx.title} está pronta. Bom apetite!',
        checkSteps: [step],
        step: step,
        mode: RecipeAssistantModes.passos,
        confidence: high,
      );
    }
    final next = step + 1;
    return _result(
      'complete_step',
      '${_ack(next)}! Passo ${step + 1} concluído. Agora, ${_stepSentence(next)}',
      checkSteps: [step],
      step: next,
      mode: RecipeAssistantModes.passos,
      confidence: high,
    );
  }

  RecipeAssistantIntent _finishAllSteps() {
    final all = [for (var i = 0; i < _stepCount; i++) if (!ctx.instructionChecked[i]) i];
    return _result(
      'complete_step',
      'Perfeito! Marquei todos os passos como concluídos. A receita ${ctx.title} está pronta. Bom apetite!',
      checkSteps: all,
      step: _stepCount - 1,
      mode: RecipeAssistantModes.passos,
      confidence: high,
    );
  }

  // Passo que o usuário diz não ter feito: o que tem o verbo/assunto citado,
  // procurando do atual para trás; sem pista, o atual (ou o último concluído)
  int _stepNotActuallyDone(_Utterance u) {
    // "desmarca esse último que você marcou"
    if (u.has(r'(ultimo|ultima) que (voce )?(marcou|marquei)|que voce (acabou de )?marcou|marcou sem querer|marcou errado')) {
      final lastChecked = ctx.instructionChecked.lastIndexOf(true);
      if (lastChecked >= 0) return lastChecked;
    }
    final words = u.content.where((w) => w.length >= 3).toList();
    var bestScore = 0;
    var best = -1;
    for (var s = _currentStep; s >= 0; s--) {
      var score = 0;
      for (final w in words) {
        if (_stepWords[s].any((sw) => RecipeLanguage.wordsMatch(w, sw) || RecipeLanguage.sameVerb(w, sw))) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    if (best >= 0) return best;
    // Logo depois de "Passo X concluído", "ainda não terminei" desfaz aquele passo
    final justCompleted = RecipeLanguage.normalize(ctx.lastResponse).contains('concluido');
    if (justCompleted &&
        !u.has(r'esse|este|nesse|neste|atual') &&
        _currentStep > 0 &&
        !ctx.instructionChecked[_currentStep] &&
        ctx.instructionChecked[_currentStep - 1]) {
      return _currentStep - 1;
    }
    return _currentStep;
  }

  RecipeAssistantIntent _uncheckStep(int index) {
    final step = _clampStep(index);
    return _result(
      'uncheck_steps',
      'Sem pressa, deixei o passo ${step + 1} como pendente. Ele diz: ${_stepText(step)}. Quando terminar, me avise.',
      uncheckSteps: [step],
      step: step,
      mode: RecipeAssistantModes.passos,
      confidence: high,
    );
  }

  RecipeAssistantIntent? _navigationIntent(_Utterance u) {
    if (_stepCount == 0) return null;
    final shortAndNow = RecipeLanguage.re(r'^(e )?(agora|e agora|e ai|e dai|e depois|depois|e entao|e o resto)$').hasMatch(u.text) ||
        RecipeLanguage.re(r'^e (agora|depois|ai|dai)\b').hasMatch(u.text) && u.words.length <= 5;

    final wantsCurrent = u.has(
      r'passo atual|etapa atual|em que (passo|etapa|parte)|em qual (passo|etapa|parte)|onde (eu )?(estou|estamos|parei|paramos|a gente parou|a gente esta)|qual (e )?(o )?passo( agora| atual)?$|qual (e )?a (etapa|parte)( agora| atual)?$|o que (eu )?(faco|devo fazer|tenho que fazer|preciso fazer|vou fazer|e para fazer|era para fazer|eu faco|faz|fazer)\b(?! (com|depois|em seguida|quando|antes))|o que fazer agora|qual e a (etapa|parte) agora|qual (e )?(o )?(passo|etapa) (que )?(eu )?(estou|estamos|a gente esta)|lembra (para mim |me )?(o passo|o que|qual)|me lembra|me perdi|estou perdid[oa]|(faco|fazer|faz) o que( agora)?$',
    );
    final wantsNext = !wantsCurrent && (shortAndNow || u.has(
      r'proximo|proxima|seguinte|avanca|avancar|avance|adiante|segue|seguir|siga|continua|continuar|continue|prossiga|prosseguir|pode ir|vai em frente|vai la|manda o proximo|manda ver|depois disso|o que vem depois|que vem depois|o que tem depois|vem o que|pula|pular|pule|passa para o|passar para o|bora para o|vamos para o|next|e depois',
    ));
    final wantsPrevious = u.has(
      r'anterior|voltar|volta|volte|retorna|retornar|retroceder|recua|recuar|o que era antes|passo de antes|antes desse|antes deste|o que (foi|era) antes|o de antes',
    );

    if (wantsPrevious && !wantsNext) {
      if (_currentStep == 0 && !_gathering) {
        return _result(
          'previous_step',
          'Você já está no primeiro passo. ${_stepSentence(0)}',
          step: 0,
          mode: RecipeAssistantModes.passos,
          confidence: high,
        );
      }
      return _goToStep(_currentStep - 1, 'previous_step');
    }
    if (wantsNext) {
      // Ainda separando ingredientes: o "próximo passo" é o primeiro do preparo
      if (_gathering && _currentStep == 0 && !ctx.instructionChecked.contains(true)) {
        return _goToStep(0, 'next_step');
      }
      if (_currentStep >= _stepCount - 1 && ctx.mode != null) {
        return _result(
          'next_step',
          'Esse já é o último passo. ${_stepSentence(_stepCount - 1)} Quando terminar, a receita está pronta!',
          step: _stepCount - 1,
          mode: RecipeAssistantModes.passos,
          confidence: high,
        );
      }
      return _goToStep(_currentStep + 1, 'next_step');
    }
    if (wantsCurrent) {
      if (_gathering && _uncheckedIngredients.isNotEmpty && !u.has(r'passo|etapa')) {
        final remaining = _uncheckedIngredients;
        return _result(
          'current_step',
          'Agora é separar os ingredientes. Ainda falta: '
              '${RecipeLanguage.joinPt(remaining.map((i) => _ingredients[i].spoken).toList())}. '
              'Quando tiver tudo, me avise que vamos ao passo 1.',
          ingredientIndex: remaining.first,
          confidence: high,
        );
      }
      return _goToStep(_currentStep, 'current_step');
    }
    return null;
  }

  RecipeAssistantIntent _goToStep(int index, String action) {
    if (_stepCount == 0) {
      return _result('general', 'Essa receita ainda não tem passos de preparo cadastrados.', confidence: high);
    }
    final step = _clampStep(index);
    var prefix = '';
    if (action == 'previous_step' && index < 0) prefix = 'Você já está no primeiro passo. ';
    if (action == 'next_step' && index >= _stepCount) prefix = 'Esse já é o último passo. ';
    if (action == 'repeat_step') prefix = 'Repetindo. ';
    return _result(
      action,
      '$prefix${_stepSentence(step)}',
      step: step,
      mode: RecipeAssistantModes.passos,
      confidence: high,
    );
  }

  RecipeAssistantIntent _explainStep(int index, {bool move = false}) {
    final step = _clampStep(index);
    final buffer = StringBuffer('No passo ${step + 1}: ${_stepText(step)}.');
    final used = <String>[];
    for (var i = 0; i < _ingredientCount; i++) {
      if (_stepsUsingIngredient(i).contains(step)) used.add(_ingredients[i].spoken);
    }
    if (used.isNotEmpty) {
      buffer.write(' Para isso, use ${RecipeLanguage.joinPt(used)}.');
    }
    final stepNorm = RecipeLanguage.normalize(ctx.instructions[step]);
    for (final entry in _glossary.entries) {
      final key = entry.key;
      final forms = key == 'untar'
          ? ['unte', 'untar']
          : key == 'preaquecer'
              ? ['preaqueca', 'preaquecer', 'pre aqueca']
              : [key];
      if (forms.any((f) => RecipeLanguage.re('\\b$f\\b').hasMatch(stepNorm))) {
        buffer.write(' ${entry.value}');
        break;
      }
    }
    return _result(
      'explain_step',
      buffer.toString(),
      step: move ? step : null,
      mode: move ? RecipeAssistantModes.passos : null,
      confidence: high,
    );
  }

  // ---------------------------------------------------------------------------
  // Ajuda, conversa e respostas genéricas
  // ---------------------------------------------------------------------------

  RecipeAssistantIntent? _helpIntent(_Utterance u, {bool strongOnly = false}) {
    // Perguntas sobre o próprio assistente valem mesmo antes das outras intenções
    final strong = u.has(
      r'(como|o que) (eu )?(uso|usar|utilizo|faco com|falo com) (voce|o assistente|esse assistente|isso aqui)|(voce|o assistente) entende (o que eu falo|portugues|fala normal|tudo|qualquer coisa)|o que (voce|tu) (sabe|consegue|pode) fazer|o que (voce|tu) (faz|sabe)$|(consegue|pode|sabe) (me )?ajudar (com|em) (o que|que)|ajudar com o que|com o que (voce )?(pode|consegue|sabe)|o que (eu )?(posso|consigo|da para) (eu )?(te |lhe )?(falar|dizer|perguntar|pedir)|(posso|consigo) (te |lhe )?(perguntar|pedir)|comandos?|falar normal|(fala|falo) normal|tem que ser (comando|certinho)|o que mais (voce|da para)|para que (voce )?serve|como (voce|isso) funciona|como funciona (voce|o assistente|isso aqui|esse assistente)|como (e que )?funciona (esse|essa|isso|o|a) ?(negocio|coisa|assistente|aplicativo|app|celular)?|falar com (o |a )?(celular|aplicativo|app|assistente|telefone|maquina|voce)|voce (faz|sabe fazer|consegue fazer|pode fazer) o que|como (eu )?(converso|falo|uso|mexo|lido) com (voce|isso|o assistente|esse assistente|essa coisa)|o que (voce )?(sabe|consegue|pode) fazer para me ajudar',
    );
    if (strongOnly && !strong) return null;
    if (!strong &&
        !u.has(
          r'ajuda|socorro|o que (voce|tu) (sabe|consegue|pode|faz)|o que (eu )?posso (falar|dizer|perguntar|pedir)|como (voce|isso|eu te|te|que eu te|eu uso|uso|que funciona|e que funciona)( funciona| uso| usar)?|como funciona|quais (sao )?(os )?comandos|como eu falo com voce|para que (voce|serve)|o que da para (fazer|pedir|perguntar)|o que mais (voce|da para)',
        )) {
      return null;
    }
    return _result(
      'help',
      'Pode falar comigo do seu jeito! Eu digo os ingredientes e as quantidades, marco o que você já pegou, '
          'leio o passo atual, avanço ou volto etapas, repito o que falei e respondo sobre tempo, '
          'temperatura e o andamento da receita ${ctx.title}. ${_contextHint()}',
      confidence: high,
    );
  }

  RecipeAssistantIntent? _smalltalkIntent(_Utterance u) {
    final greeting = RecipeLanguage.re(
      r'^(oi|ola|opa|e ai|eai|bom dia|boa tarde|boa noite|tudo bem|tudo bom|salve|hey|alo|oi assistente|ola assistente)\b',
    ).hasMatch(u.text);
    final thanks = u.has(
      r'obrigad\w*|valeu|agradec\w*|vlw|gratidao|que legal|show de bola|maravilha|excelente|legal|top|bacana|otimo|perfeito|show|beleza|entendi|certo|combinado|ok|okay|ta bom|esta bom|uhum|aham',
    );
    if (!greeting && !thanks) return null;
    // "beleza, o que eu pego primeiro?" é pergunta, não conversa
    if (u.has(r'o que|qual|quais|cade|onde|quanto|quantos|quantas|como|por onde|quando|sera')) return null;
    final gratitudeWords = u.has(r'obrigad\w*|valeu|agradec\w*|vlw|gratidao|deus te abencoe');
    if (u.words.length > 8 && !gratitudeWords) return null;
    if (greeting && !thanks) {
      return _result('smalltalk', 'Oi! Estou aqui para te ajudar com a receita ${ctx.title}. ${_contextHint()}', confidence: high);
    }
    final gratitude = u.has(r'obrigad\w*|valeu|agradec\w*|vlw|gratidao');
    return _result(
      'smalltalk',
      '${gratitude ? 'De nada!' : 'Combinado!'} ${_contextHint()}',
      confidence: high,
    );
  }

  RecipeAssistantIntent _fallbackIntent(_Utterance u) {
    // Ingrediente citado sem verbo ("e a farinha?") -> informa sobre ele
    final mentions = _mentions(u.words);
    if (mentions.isNotEmpty) {
      final answer = _presenceAnswer(mentions, u);
      return _result(
        answer.action,
        answer.responseText,
        confidence: medium,
      );
    }

    // Trecho de algum passo ("como faço a cobertura?")
    final step = _bestMatchingStep(u);
    if (step != null && _stepMatchScore(u, step) >= 1 && u.content.isNotEmpty) {
      final distinctive = u.content.where((w) => w.length >= 5).length;
      if (_stepMatchScore(u, step) >= 2 || distinctive > 0) {
        return _result(
          'explain_step',
          'Isso aparece no passo ${step + 1}: ${_stepText(step)}.',
          confidence: medium,
        );
      }
    }

    // Repete o que foi ouvido: se o reconhecimento de voz errou, a pessoa percebe
    final heard = u.raw.trim().length > 80 ? '${u.raw.trim().substring(0, 80)}...' : u.raw.trim();
    if (_looksRecipeRelated(u)) {
      return _result(
        'general',
        'Ouvi "$heard", mas não entendi bem. ${_contextHint()}',
        pending: _stepCount > 0 && _cooking ? 'current_step' : null,
        confidence: low,
      );
    }
    // A recusa ("só ajudo com a receita") fica para assuntos claramente fora,
    // detectados antes; aqui a fala só não foi entendida
    return _result(
      'general',
      'Ouvi "$heard", mas não entendi bem. Posso ajudar com os ingredientes, as quantidades e os passos da receita ${ctx.title}.',
      confidence: low,
    );
  }

  int _stepMatchScore(_Utterance u, int step) {
    var score = 0;
    for (final w in u.content.where((w) => w.length >= 3)) {
      if (_stepWords[step].any((sw) => RecipeLanguage.wordsMatch(w, sw))) score++;
    }
    return score;
  }

  bool _looksRecipeRelated(_Utterance u) =>
      u.has(
        r'receita|ingrediente|passo|etapa|preparo|cozinha|cozinhar|fazer|faz|faco|preparar|forno|fogo|massa|bolo|prato|panela|tigela|forma|frigideira|assadeira|misturar|mexer|bater|assar|cortar|picar|temperar|tempero|sal|doce|quantidade|medida|xicara|colher|gramas|cobrir|cobre|tampar|tampa|virar|vira|escorrer|descascar|ferver|refogar|untar|enrolar|rechear|servir|sirvo',
      ) ||
      u.words.any((w) => RecipeLanguage.contentWords(ctx.title).any((t) => RecipeLanguage.wordsMatch(w, t))) ||
      u.content.any((w) => _stepWords.any((sw) => sw.any((s) => RecipeLanguage.sameVerb(w, s))));

  String _contextHint() {
    if (_cooking && _stepCount > 0) {
      return 'Estamos no passo ${_currentStep + 1}. Quando terminar, é só me avisar, ou peça para eu repetir.';
    }
    if (_ingredientCount > 0 && _uncheckedIngredients.isNotEmpty) {
      return 'Me avise quando pegar os ingredientes, ou pergunte a quantidade de algum deles.';
    }
    if (_stepCount > 0) {
      return 'Quando quiser, peça para começar o preparo.';
    }
    return 'Pode me perguntar o que quiser sobre a receita.';
  }

  // ---------------------------------------------------------------------------
  // Identificação de ingredientes na fala
  // ---------------------------------------------------------------------------

  List<_Mention> _mentions(List<String> words) {
    final candidates = <_Mention>[];
    final contentPositions = <int>[
      for (var p = 0; p < words.length; p++)
        if (!RecipeLanguage.stopwords.contains(words[p]) &&
            !RecipeLanguage.re(r'^\d+(\.\d+)?$').hasMatch(words[p]))
          p,
    ];
    if (contentPositions.isEmpty) return const [];

    // Qualidade do casamento de uma palavra falada com uma palavra do ingrediente;
    // adjetivos ("gelado") não casam com substantivos ("gelo")
    int quality(String spoken, String key) {
      if (RecipeLanguage.weakDescriptors.contains(spoken) && !RecipeLanguage.weakDescriptors.contains(key)) {
        return 0;
      }
      if (RecipeLanguage.looksLikeParticiple(spoken) && !RecipeLanguage.looksLikeParticiple(key) && spoken != key) {
        return 0;
      }
      return RecipeLanguage.matchQuality(spoken, key);
    }

    // Para cada palavra falada, só valem os ingredientes com o melhor casamento:
    // "pimenta" igual a "pimenta-do-reino" vence "pimentão" parecido
    final bestAt = <int, int>{};
    for (final p in contentPositions) {
      var best = 0;
      for (final ing in _ingredients) {
        for (final key in ing.keyWords) {
          final q = quality(words[p], key);
          if (q > best) best = q;
        }
      }
      bestAt[p] = best;
    }

    for (var i = 0; i < _ingredients.length; i++) {
      final ing = _ingredients[i];
      var score = 0.0;
      var headMatched = false;
      var strongMatched = false;
      final positions = <int>{};
      for (var k = 0; k < ing.keyWords.length; k++) {
        final key = ing.keyWords[k];
        for (final p in contentPositions) {
          if (positions.contains(p)) continue;
          final q = quality(words[p], key);
          if (q > 0 && q >= bestAt[p]!) {
            positions.add(p);
            if (k == 0) {
              score += 2;
              headMatched = true;
              strongMatched = true;
            } else if (ing.isWeak(key)) {
              score += 0.3;
            } else {
              score += 1;
              strongMatched = true;
            }
            break;
          }
        }
      }
      if (strongMatched && score >= 1) {
        candidates.add(_Mention(i, score, headMatched, positions));
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final kept = <_Mention>[];
    for (final c in candidates) {
      final dominated = kept.any((k) => k.score > c.score && c.positions.every(k.positions.contains));
      if (!dominated) kept.add(c);
    }
    kept.sort((a, b) => a.positions.reduce((x, y) => x < y ? x : y).compareTo(b.positions.reduce((x, y) => x < y ? x : y)));
    return kept;
  }

  // ---------------------------------------------------------------------------
  // Utilitários de resposta
  // ---------------------------------------------------------------------------

  bool _isQuestion(_Utterance u) =>
      u.raw.contains('?') ||
      u.starts(r'qual|quais|quanto|quantos|quantas|como|quando|onde|o que|que|sera|por que|porque|pode me dizer|me diz|me diga|sabe|e o|e a|tem|leva|vai|precisa') ||
      u.has(r'sera que|voce sabe|pode me dizer|me fala|me diz|me diga|qual|quanto|quantos|quantas|o que e|o que significa|o que quer dizer|e o que');

  String _stepText(int index) {
    if (index < 0 || index >= _stepCount) return '';
    return RecipeLanguage.trimEnd(RecipeLanguage.speakable(ctx.instructions[index]));
  }

  String _stepSentence(int index) => 'Passo ${index + 1}: ${_stepText(index)}.';

  String _ack(int seed) {
    const options = ['Certo', 'Beleza', 'Ótimo', 'Perfeito'];
    return options[seed.abs() % options.length];
  }

  String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  RecipeAssistantIntent _result(
    String action,
    String text, {
    int? step,
    List<int> checkIngredients = const [],
    List<int> uncheckIngredients = const [],
    List<int> checkSteps = const [],
    List<int> uncheckSteps = const [],
    int? ingredientIndex,
    String? mode,
    bool stop = false,
    String? pending,
    double confidence = high,
  }) {
    return RecipeAssistantIntent(
      action: action,
      stepIndex: step == null ? _currentStep : _clampStep(step),
      responseText: text.replaceAll(RecipeLanguage.re(r'\s+'), ' ').trim(),
      checkIngredients: checkIngredients,
      uncheckIngredients: uncheckIngredients,
      checkSteps: checkSteps,
      uncheckSteps: uncheckSteps,
      ingredientIndex: ingredientIndex,
      mode: mode,
      stopAssistant: stop,
      pendingAction: pending,
      confidence: confidence,
      source: 'local',
    );
  }
}

// Fala já normalizada e com variações coloquiais padronizadas
class _Utterance {
  final String raw;
  final String text;
  final List<String> words;
  final List<String> content;

  _Utterance._(this.raw, this.text, this.words, this.content);

  factory _Utterance.parse(String raw, {bool alreadyNormalized = false}) {
    final text = _canonical(alreadyNormalized ? raw : RecipeLanguage.normalize(raw));
    final words = RecipeLanguage.tokens(text);
    final content = words
        .where((w) => !RecipeLanguage.stopwords.contains(w) && !RecipeLanguage.re(r'^\d+(\.\d+)?$').hasMatch(w))
        .toList();
    return _Utterance._(raw, text, words, content);
  }

  static const Map<String, String> _colloquial = {
    'pro': 'para o', 'pra': 'para', 'pros': 'para os', 'pras': 'para as',
    'ce': 'voce', 'oce': 'voce', 'vc': 'voce', 'to': 'estou',
    'tamo': 'estamos', 'tao': 'estao', 'ta': 'esta', 'tava': 'estava',
    'cade': 'onde esta', 'q': 'que', 'n': 'nao', 'pegei': 'peguei',
    'tbm': 'tambem', 'tb': 'tambem', 'blz': 'beleza',
    'vlw': 'valeu', 'pq': 'porque', 'mto': 'muito', 'oque': 'o que',
    'vamo': 'vamos', 'pacos': 'passos', 'paco': 'passo',
    'brigadao': 'obrigado', 'brigado': 'obrigado', 'brigada': 'obrigada',
    'obrigadao': 'obrigado', 'obg': 'obrigado', 'comecinho': 'comeco',
    'iniciozinho': 'inicio', 'finalzinho': 'final', 'passinho': 'passo',
    'qnto': 'quanto', 'qnt': 'quanto', 'qto': 'quanto', 'qntos': 'quantos',
    'qnts': 'quantos', 'qntas': 'quantas', 'qnd': 'quando', 'qdo': 'quando',
    'oq': 'o que', 'vdd': 'verdade', 'agr': 'agora', 'dnv': 'de novo',
    'nd': 'nada', 'olio': 'oleo', 'tudinho': 'tudo', 'todinhos': 'todos',
    'todinhas': 'todas', 'terseiro': 'terceiro', 'terseira': 'terceira',
    'sesto': 'sexto', 'sesta': 'sexta', 'utimo': 'ultimo', 'utima': 'ultima',
    'assistenti': 'assistente', 'sistente': 'assistente', 'dps': 'depois',
    'tu': 'voce', 'separadinhos': 'separados',
    'separadinho': 'separado', 'separadinha': 'separada', 'td': 'tudo', 'tds': 'todos', 'mt': 'muito',
    'pfv': 'por favor', 'pf': 'por favor', 'eae': 'e ai', 'iae': 'e ai',
    'inteirinho': 'inteiro', 'inteirinha': 'inteira', 'todinho': 'todo',
    'todinha': 'toda', 'douradinho': 'dourado', 'douradinha': 'dourada',
    'douradinhos': 'dourados', 'limpinho': 'limpo', 'direitinho': 'direito',
    'rapidinho': 'rapido', 'pouquinho': 'pouco', 'quentinho': 'quente',
    'molinho': 'mole', 'cozidinho': 'cozido', 'catchup': 'ketchup',
    'prox': 'proximo', 'msm': 'mesmo',
  };

  static const Set<String> _fillers = {
    'ne', 'ahn', 'hmm', 'hmmm', 'uhm', 'humm', 'eh', 'tipo', 'entao', 'olha', 'cara',
    'mano', 'velho', 'meu', 'filho', 'amigo', 'querido', 'querida', 'ow', 'oh',
    'ei', 'psiu', 'tlg', 'vey', 'vei', 'kkk', 'kkkk', 'rs', 'rsrs', 'mds',
  };

  static String _canonical(String normalized) {
    final words = RecipeLanguage.tokens(normalized);
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      // "tipo" só é muleta quando não pergunta "que tipo de..."
      if (_fillers.contains(w) && !(w == 'tipo' && i > 0 && words[i - 1] == 'que')) {
        if (!(w == 'meu' && i + 1 < words.length)) continue;
      }
      // "pô" no começo é interjeição, não "fermento em pó"
      if (w == 'po' && out.isEmpty && words.length > 1) continue;
      if (w == 'num' && i + 1 < words.length &&
          RecipeLanguage.re(r'^(tenho|peguei|achei|sei|entendi|fiz|terminei|consegui|tem|esta|ta|quero|precisa|vou|acabei|separei|comprei|ouvi)$')
              .hasMatch(words[i + 1])) {
        out.add('nao');
        continue;
      }
      out.add(_colloquial[w] ?? w);
    }
    // "o que que eu faço", "onde que eu parei" -> forma direta
    return out
        .join(' ')
        .replaceAll(RecipeLanguage.re(r'\bque que\b'), 'que')
        .replaceAllMapped(
          RecipeLanguage.re(r'\b(o que|como|onde|quando|quem|qual) e que\b'),
          (m) => m.group(1)!,
        )
        .replaceAllMapped(
          RecipeLanguage.re(r'\b(onde|como|quando|qual|quais|quanto|quantos|quantas|quem) que\b'),
          (m) => m.group(1)!,
        );
  }

  bool has(String pattern) => RecipeLanguage.re('\\b(?:$pattern)\\b').hasMatch(text);

  bool starts(String pattern) => RecipeLanguage.re('^(?:$pattern)\\b').hasMatch(text);
}

class _Mention {
  final int index;
  final double score;
  final bool headMatched;
  final Set<int> positions;

  _Mention(this.index, this.score, this.headMatched, this.positions);

  int get firstPosition => positions.isEmpty ? 0 : positions.reduce((a, b) => a < b ? a : b);
}

// Intervalo de palavras [start, end] onde uma pista aparece na fala
class _Span {
  final int start;
  final int end;

  _Span(this.start, this.end);

  bool overlaps(_Span other) => start <= other.end && other.start <= end;
}

class _StepRef {
  final int index;
  final bool outOfRange;

  _StepRef(this.index, int count) : outOfRange = index < 0 || index >= count;
}

class _TimeMention {
  final int step;
  final double minutes;
  final String text;

  _TimeMention(this.step, this.minutes, this.text);
}
