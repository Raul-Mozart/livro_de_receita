// Utilitários de linguagem (pt-BR) usados pelo assistente de receitas:
// normalização da fala, comparação aproximada de palavras, leitura de números
// e formatação de ingredientes para serem falados pelo TTS.

class RecipeLanguage {
  RecipeLanguage._();

  // Caches: compilar expressões e recalcular comparações a cada fala deixaria
  // o assistente lento no celular
  static final Map<String, RegExp> _regexCache = {};
  static final Map<String, String> _normalizeCache = {};
  static final Map<String, String> _rootCache = {};
  static final Map<String, String> _phoneticCache = {};
  static final Map<String, int> _qualityCache = {};

  /// Expressão regular compilada uma única vez por padrão.
  static RegExp re(String pattern) => _regexCache.putIfAbsent(pattern, () => RegExp(pattern));

  static V _memo<V>(Map<String, V> cache, String key, V Function() compute) {
    final cached = cache[key];
    if (cached != null) return cached;
    if (cache.length > 20000) cache.clear();
    return cache[key] = compute();
  }

  // Palavras sem conteúdo útil para identificar ingredientes ou passos
  static const Set<String> stopwords = {
    'a', 'o', 'as', 'os', 'um', 'uma', 'uns', 'umas', 'de', 'da', 'do', 'das',
    'dos', 'em', 'na', 'no', 'nas', 'nos', 'num', 'numa', 'e', 'ou', 'com',
    'sem', 'por', 'para', 'pra', 'pro', 'pros', 'pras', 'que', 'se', 'ja', 'eu',
    'voce', 'ce', 'vc', 'me', 'mim', 'te', 'ele', 'ela', 'isso', 'isto', 'esse',
    'essa', 'este', 'esta', 'estes', 'estas', 'esses', 'essas', 'aquele',
    'aquela', 'nessa', 'nesse', 'neste', 'nesta', 'nisso', 'dessa', 'desse',
    'deste', 'desta', 'disso', 'ai', 'aqui', 'ali', 'la', 'entao', 'tipo', 'ne',
    'ta', 'to', 'so', 'mais', 'muito', 'muita', 'pouco', 'bem', 'tambem',
    'agora', 'depois', 'antes', 'ainda', 'quando', 'onde', 'como', 'qual',
    'quais', 'quanto', 'quantos', 'quanta', 'quantas', 'porque', 'pois', 'mas',
    'sim', 'nao', 'ok', 'vai', 'vou', 'foi', 'ser', 'era', 'estar', 'estou',
    'estamos', 'estao', 'tem', 'tenho', 'temos', 'ter', 'ha', 'faz', 'faco',
    'fazer', 'fiz', 'pode', 'posso', 'podemos', 'quer', 'quero', 'preciso',
    'precisa', 'precisar', 'dizer', 'diz', 'diga', 'fala', 'falar', 'fale',
    'meu', 'minha', 'nosso', 'nossa', 'seu', 'sua', 'ao', 'aos', 'pelo',
    'pela', 'ate', 'sobre', 'cada', 'todo', 'toda', 'todos', 'todas', 'tudo',
    'nada', 'algo', 'alguma', 'algum', 'coisa', 'coisas', 'receita',
    'ingrediente', 'ingredientes', 'item', 'itens', 'passo', 'passos', 'etapa',
    'etapas', 'parte', 'hora', 'vez', 'gente', 'favor', 'obrigado', 'obrigada',
    'leva', 'levar', 'usa', 'usar', 'uso', 'usado', 'usada', 'coloca',
    'colocar', 'coloco', 'ponho', 'boto', 'entra', 'peguei', 'pego', 'pegar',
    'pegue', 'separei', 'separar', 'achei', 'comprei', 'consegui', 'falta',
    'faltou', 'faltam', 'acabou', 'desmarca', 'desmarcar', 'desmarque', 'marca',
    'marcar', 'marque', 'quantidade', 'medida', 'sera', 'sabe', 'saber',
    'preparo', 'modo', 'vem', 'tinha', 'dar', 'manda', 'ver', 'certo',
    'beleza', 'pronto', 'pronta', 'aham', 'uhum', 'hum', 'eh', 'ah', 'olha',
    'assistente', 'oi', 'ola', 'ei', 'tal', 'mesmo', 'mesma', 'outra', 'outro',
    'qualquer', 'alguem', 'adiciono', 'acrescento', 'junto', 'misturo', 'bota',
    'gentileza', 'querida', 'querido', 'filha', 'filho', 'senhora', 'moca',
  };

  // Descrições que, sozinhas, não identificam um ingrediente
  static const Set<String> weakDescriptors = {
    'po', 'meio', 'meia', 'amargo', 'amarga', 'picado', 'picada', 'picados',
    'picadas', 'ralado', 'ralada', 'ralados', 'raladas', 'fresco', 'fresca',
    'frescos', 'frescas', 'grande', 'grandes', 'pequeno', 'pequena',
    'pequenos', 'pequenas', 'medio', 'media', 'medios', 'medias', 'maduro',
    'madura', 'maduros', 'maduras', 'derretido', 'derretida', 'gelado',
    'gelada', 'morno', 'morna', 'quente', 'frio', 'fria', 'refinado',
    'refinada', 'cristal', 'tipo', 'extra', 'virgem', 'peneirado', 'peneirada',
    'cozido', 'cozida', 'cozidos', 'cozidas', 'gosto', 'opcional',
  };

  // Unidades compostas (mais longas primeiro) e simples, já normalizadas
  static const List<List<String>> _multiWordUnits = [
    ['colheres', 'de', 'sopa'],
    ['colher', 'de', 'sopa'],
    ['colheres', 'de', 'cha'],
    ['colher', 'de', 'cha'],
    ['colheres', 'de', 'sobremesa'],
    ['colher', 'de', 'sobremesa'],
    ['colheres', 'de', 'cafe'],
    ['colher', 'de', 'cafe'],
    ['xicaras', 'de', 'cha'],
    ['xicara', 'de', 'cha'],
    ['copos', 'americanos'],
    ['copo', 'americano'],
    ['a', 'gosto'],
  ];

  static const Set<String> _singleWordUnits = {
    'g', 'gr', 'grs', 'grama', 'gramas', 'kg', 'kgs', 'quilo', 'quilos', 'kilo',
    'kilos', 'quilograma', 'quilogramas', 'mg', 'ml', 'mililitro',
    'mililitros', 'l', 'lt', 'lts', 'litro', 'litros', 'xicara', 'xicaras',
    'xic', 'colher', 'colheres', 'col', 'copo', 'copos', 'lata', 'latas',
    'caixa', 'caixas', 'caixinha', 'caixinhas', 'pacote', 'pacotes',
    'unidade', 'unidades', 'un', 'und', 'unid', 'pitada', 'pitadas', 'dente',
    'dentes', 'fatia', 'fatias', 'folha', 'folhas', 'maco', 'macos', 'ramo',
    'ramos', 'punhado', 'punhados', 'gota', 'gotas', 'sache', 'saches',
    'envelope', 'envelopes', 'tablete', 'tabletes', 'barra', 'barras', 'pote',
    'potes', 'vidro', 'vidros', 'garrafa', 'garrafas', 'cubo', 'cubos', 'talo',
    'talos', 'pedaco', 'pedacos', 'porcao', 'porcoes', 'bandeja', 'bandejas',
    'saco', 'sacos', 'cabeca', 'cabecas', 'posta', 'postas', 'fio', 'fios',
    'copinho', 'copinhos', 'colherzinha', 'colherinha',
  };

  // Abreviações que soam mal no TTS: [singular, plural]
  static const Map<String, List<String>> _spokenUnits = {
    'g': ['grama', 'gramas'],
    'gr': ['grama', 'gramas'],
    'grs': ['grama', 'gramas'],
    'kg': ['quilo', 'quilos'],
    'kgs': ['quilo', 'quilos'],
    'mg': ['miligrama', 'miligramas'],
    'ml': ['mililitro', 'mililitros'],
    'l': ['litro', 'litros'],
    'lt': ['litro', 'litros'],
    'lts': ['litro', 'litros'],
    'un': ['unidade', 'unidades'],
    'und': ['unidade', 'unidades'],
    'unid': ['unidade', 'unidades'],
    'xic': ['xícara', 'xícaras'],
    'col': ['colher', 'colheres'],
  };

  static const Map<String, int> numberWords = {
    'um': 1, 'uma': 1, 'primeiro': 1, 'primeira': 1,
    'dois': 2, 'duas': 2, 'segundo': 2, 'segunda': 2,
    'tres': 3, 'terceiro': 3, 'terceira': 3,
    'quatro': 4, 'quarto': 4, 'quarta': 4,
    'cinco': 5, 'quinto': 5, 'quinta': 5,
    'seis': 6, 'sexto': 6, 'sexta': 6,
    'sete': 7, 'setimo': 7, 'setima': 7,
    'oito': 8, 'oitavo': 8, 'oitava': 8,
    'nove': 9, 'nono': 9, 'nona': 9,
    'dez': 10, 'decimo': 10, 'decima': 10,
    'onze': 11, 'doze': 12, 'treze': 13, 'catorze': 14, 'quatorze': 14,
    'quinze': 15, 'dezesseis': 16, 'dezessete': 17, 'dezoito': 18,
    'dezenove': 19, 'vinte': 20,
  };

  static const Set<String> ordinalWords = {
    'primeiro', 'primeira', 'segundo', 'segunda', 'terceiro', 'terceira',
    'quarto', 'quarta', 'quinto', 'quinta', 'sexto', 'sexta', 'setimo',
    'setima', 'oitavo', 'oitava', 'nono', 'nona', 'decimo', 'decima',
  };

  /// Minúsculas, sem acentos e sem pontuação (preserva decimais como "2.5").
  static String normalize(String text) => _memo(_normalizeCache, text, () => _normalizeImpl(text));

  static String _normalizeImpl(String text) {
    var t = text.toLowerCase();
    // "180°" / "180 ºC" viram graus; "3º passo" vira ordinal simples
    t = t.replaceAllMapped(re(r'(\d+)\s*[°º]\s*c?\b'), (m) {
      final value = int.tryParse(m.group(1)!) ?? 0;
      return value >= 50 ? '${m.group(1)} graus ' : '${m.group(1)} ';
    });
    t = t.replaceAll(re(r'[°ºª]'), ' ');
    t = t
        .replaceAll(re(r'[áàâãä]'), 'a')
        .replaceAll(re(r'[éèêë]'), 'e')
        .replaceAll(re(r'[íìîï]'), 'i')
        .replaceAll(re(r'[óòôõö]'), 'o')
        .replaceAll(re(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
    t = t.replaceAllMapped(re(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');
    t = t.replaceAll(re(r'[^a-z0-9\s.]'), ' ');
    t = t.replaceAll(re(r'(?<!\d)\.|\.(?!\d)'), ' ');
    return t.replaceAll(re(r'\s+'), ' ').trim();
  }

  static List<String> tokens(String normalized) =>
      normalized.split(' ').where((w) => w.isNotEmpty).toList();

  /// Reduz plural para comparar "ovos" com "ovo", "limões" com "limão" etc.
  static String singular(String w) {
    if (w.length <= 3) return w;
    if (w.endsWith('oes') || w.endsWith('aes')) {
      return '${w.substring(0, w.length - 3)}ao';
    }
    if (w.endsWith('eis') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}el';
    }
    if (w.endsWith('ais') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}al';
    }
    if (w.endsWith('ns')) return '${w.substring(0, w.length - 2)}m';
    if (w.endsWith('res') || w.endsWith('zes') || w.endsWith('les')) {
      return w.substring(0, w.length - 2);
    }
    if (w.endsWith('s') && !w.endsWith('ss')) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  static const List<String> _rootEndings = [
    'ando', 'endo', 'indo', 'ados', 'adas', 'idos', 'idas', 'ado', 'ada',
    'ido', 'ida', 'ar', 'er', 'ir', 'ei', 'ou', 'eu', 'iu', 'a', 'e', 'i', 'o',
  ];

  /// Raiz aproximada para casar verbos e flexões ("asse" ~ "assar").
  static String root(String word) => _memo(_rootCache, word, () => _rootImpl(word));

  static String _rootImpl(String word) {
    // "descasque" ~ "descascar", "pegue" ~ "pegar"
    final w = singular(word)
        .replaceAllMapped(re(r'qu(?=[ei])'), (_) => 'c')
        .replaceAllMapped(re(r'gu(?=[ei])'), (_) => 'g');
    if (w.length < 4) return w;
    for (final ending in _rootEndings) {
      if (w.endsWith(ending) && w.length - ending.length >= 3) {
        return w.substring(0, w.length - ending.length);
      }
    }
    return w;
  }

  static int levenshtein(String a, String b, {int max = 3}) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > max) return max + 1;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (current[j] < rowMin) rowMin = current[j];
      }
      if (rowMin > max) return max + 1;
      previous = current;
    }
    return previous[b.length];
  }

  /// Chave fonética simples do português: aproxima grafias que soam igual
  /// ("xampinhon" ~ "champignon", "catchup" ~ "ketchup", "sau" ~ "sal").
  static String phonetic(String word) => _memo(_phoneticCache, word, () => _phoneticImpl(word));

  static String _phoneticImpl(String word) {
    var w = singular(word);
    w = w
        .replaceAll('ch', 'x')
        .replaceAll('sh', 'x')
        .replaceAll('gn', 'nh')
        .replaceAll('ph', 'f')
        .replaceAll('y', 'i')
        .replaceAll('w', 'u')
        .replaceAllMapped(re(r'qu([ei])'), (m) => 'k${m[1]}')
        .replaceAll('qu', 'ku')
        .replaceAllMapped(re(r'c([aou])'), (m) => 'k${m[1]}')
        .replaceAllMapped(re(r'c([ei])'), (m) => 's${m[1]}')
        .replaceAll('ss', 's')
        .replaceAll('z', 's')
        .replaceAllMapped(re(r'([aeiou])s([aeiou])'), (m) => '${m[1]}z${m[2]}')
        .replaceAll(re(r'(?<![lcn])h'), '')
        .replaceAll(re(r'l$'), 'u')
        .replaceAll(re(r'l(?=[^aeiouh])'), 'u');
    return w.replaceAllMapped(re(r'(.)\1+'), (m) => m[1]!);
  }

  /// Raiz com "i" e "e" unificados ("sirva" ~ "servi").
  static String _looseRoot(String word) => root(word).replaceAll('i', 'e');

  /// Compara uma palavra falada com uma palavra da receita tolerando
  /// plural, flexão verbal e pequenos erros do reconhecimento de voz.
  static bool wordsMatch(String spoken, String target) => matchQuality(spoken, target) > 0;

  /// Qualidade do casamento: 3 igual (ou plural), 2 mesma raiz,
  /// 1 parecida (som, vogal trocada, erro de digitação), 0 diferente.
  static int matchQuality(String spoken, String target) =>
      _memo(_qualityCache, '$spoken|$target', () => _matchQualityImpl(spoken, target));

  static int _matchQualityImpl(String spoken, String target) {
    if (spoken == target) return 3;
    if (spoken.length < 3 || target.length < 3) return 0;
    if (singular(spoken) == singular(target)) return 3;
    if (root(spoken) == root(target)) return 2;
    return _looselyMatches(spoken, target) ? 1 : 0;
  }

  static bool _looselyMatches(String spoken, String target) {
    final pa = phonetic(spoken);
    final pb = phonetic(target);
    if (pa == pb) return true;
    final a = singular(spoken);
    final b = singular(target);
    // "pimentão" não é erro de "pimenta", nem "limão" de "lima"
    if (a.endsWith('ao') != b.endsWith('ao')) return false;
    // Troca de uma vogal com som parecido ("olio" ~ "oleo", "tumate" ~ "tomate")
    if (a.length >= 4 && a.length == b.length) {
      var diffs = 0;
      var similarVowels = true;
      for (var i = 0; i < a.length && diffs <= 1; i++) {
        if (a[i] == b[i]) continue;
        diffs++;
        final pair = '${a[i]}${b[i]}';
        similarVowels = const {'ei', 'ie', 'ou', 'uo'}.contains(pair);
      }
      if (diffs == 1 && similarVowels) return true;
    }
    if (a.length >= 6 && b.length >= 6) {
      if (levenshtein(a, b, max: 1) <= 1 || levenshtein(pa, pb, max: 1) <= 1) {
        return true;
      }
    }
    if (a.length >= 9 && b.length >= 9 && levenshtein(a, b, max: 2) <= 2) {
      return true;
    }
    // Palavras mais curtas com o mesmo começo ("manteja" ~ "manteiga")
    if (a.length >= 7 && b.length >= 7 && a.substring(0, 4) == b.substring(0, 4) &&
        levenshtein(a, b, max: 2) <= 2) {
      return true;
    }
    return false;
  }

  /// Compara a forma verbal falada com um verbo do passo ("misturei" ~ "misture").
  static bool sameVerb(String spoken, String target) {
    if (spoken.length < 3 || target.length < 3) return false;
    return root(spoken) == root(target) || _looseRoot(spoken) == _looseRoot(target);
  }

  static bool isUnitWord(String normalizedWord) =>
      _singleWordUnits.contains(normalizedWord);

  /// "gelado", "aguada", "picados": adjetivo/particípio, não o nome do ingrediente.
  static bool looksLikeParticiple(String word) =>
      word.length > 5 && re(r'(ado|ada|ados|adas|ido|ida|idos|idas)$').hasMatch(word);

  static int? parseNumberToken(String token) {
    final parsed = int.tryParse(token);
    if (parsed != null) return parsed;
    return numberWords[token];
  }

  /// Palavras de conteúdo de um texto (sem stopwords), já normalizadas.
  static List<String> contentWords(String text) {
    return tokens(normalize(text))
        .where((w) => !stopwords.contains(w) && !_isNumeric(w))
        .toList();
  }

  static bool _isNumeric(String w) => re(r'^\d+(\.\d+)?$').hasMatch(w);

  /// Formata número para fala: 2.0 -> "2", 2.5 -> "2,5".
  static String formatNumber(double value) {
    if (!value.isFinite || value.abs() >= 1e15) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(re(r'0+$'), '').replaceFirst(re(r'\.$'), '');
    return text.replaceAll('.', ',');
  }

  /// Junta itens em português: "a, b e c".
  static String joinPt(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} e ${items.last}';
  }

  /// Ajusta o texto de um passo para soar bem no TTS.
  static String speakable(String text) {
    var t = text.trim();
    t = t.replaceAllMapped(
      re(r'(\d+)\s*[°º]\s*[cC]?\b'),
      (m) => '${m.group(1)} graus',
    );
    t = t.replaceAllMapped(
      re(r'(\d+)\.(\d+)'),
      (m) => '${m.group(1)},${m.group(2)}',
    );
    return t.replaceAll(re(r'\s+'), ' ');
  }

  /// Remove pontuação final para evitar ".." ao montar frases.
  static String trimEnd(String text) =>
      text.trim().replaceFirst(re(r'[\s.;:!,]+$'), '');

  static final RegExp _fractionPattern = re(r'^(\d{1,6})/(\d{1,6})$');
  static final RegExp _gluedPattern = re(r'^(\d+(?:[.,]\d+)?)([a-zA-Z]+)$');
  static const Map<String, double> _fractionChars = {'½': 0.5, '¼': 0.25, '¾': 0.75};

  // Lê a quantidade no começo das palavras: (quantidade, palavras usadas, unidade colada)
  static (double?, int, String) _leadingQuantity(List<String> words) {
    if (words.isEmpty) return (null, 0, '');
    final first = words[0];
    final glued = _gluedPattern.firstMatch(first);
    if (glued != null) {
      final q = double.tryParse(glued.group(1)!.replaceAll(',', '.'));
      if (q != null && q.isFinite) return (q, 1, glued.group(2)!);
    }
    final fraction = _fractionPattern.firstMatch(first);
    if (fraction != null) {
      final n = int.tryParse(fraction.group(1)!);
      final d = int.tryParse(fraction.group(2)!);
      return (n == null || d == null || d == 0 ? null : n / d, 1, '');
    }
    if (_fractionChars.containsKey(first)) return (_fractionChars[first], 1, '');
    final number = double.tryParse(first.replaceAll(',', '.'));
    if (number != null && number.isFinite && number.abs() < 1e9) {
      // "1 1/2 xícara"
      if (words.length > 1) {
        final extra = _fractionPattern.firstMatch(words[1]);
        if (extra != null) {
          final n = int.tryParse(extra.group(1)!);
          final d = int.tryParse(extra.group(2)!);
          if (n != null && d != null && d != 0) return (number + n / d, 2, '');
        }
      }
      return (number, 1, '');
    }
    // Número absurdo ("Infinity", "1e+400", fração gigante): ignora a quantidade
    if (number != null ||
        re(r'^[\d.,eE+\-/]+$').hasMatch(first) ||
        first == 'Infinity' ||
        first == 'NaN') {
      return (null, 1, '');
    }
    return (null, 0, '');
  }

  static ParsedIngredient parseIngredient(String raw) {
    final original = raw.trim();
    var words = original.split(re(r'\s+')).where((w) => w.isNotEmpty).toList();
    var (quantity, i, unit) = _leadingQuantity(words);
    var toTaste = false;

    String consumeUnit() {
      if (i >= words.length) return '';
      final normalizedRest = words.sublist(i).map(normalize).toList();
      var consumed = 0;
      for (final multi in _multiWordUnits) {
        if (normalizedRest.length >= multi.length) {
          var matches = true;
          for (var k = 0; k < multi.length; k++) {
            if (normalizedRest[k] != multi[k]) {
              matches = false;
              break;
            }
          }
          if (matches) {
            consumed = multi.length;
            break;
          }
        }
      }
      if (consumed == 0) {
        final first = normalizedRest.first;
        final followedByDe = normalizedRest.length > 1 &&
            const {'de', 'do', 'da', 'dos', 'das'}.contains(normalizedRest[1]);
        if (_singleWordUnits.contains(first) ||
            (quantity != null && followedByDe && first != 'de' && first != 'a')) {
          consumed = 1;
        }
      }
      if (consumed == 0) return '';
      // Qualificador entre parênteses faz parte da unidade: "xícara (chá)"
      if (i + consumed < words.length && re(r'^\(.*\)$').hasMatch(words[i + consumed])) {
        consumed++;
      }
      final found = words.sublist(i, i + consumed).join(' ');
      i += consumed;
      return found;
    }

    if (unit.isEmpty) unit = consumeUnit();
    if (normalize(unit) == 'a gosto') {
      toTaste = true;
      unit = '';
    }
    if (i < words.length && const {'de', 'do', 'da', 'dos', 'das'}.contains(normalize(words[i]))) {
      i++;
    }

    var nameWords = words.sublist(i);
    // Formato do banco para itens importados: "0.0  de 1/2 xícara de leite"
    if ((quantity == null || quantity <= 0) && unit.isEmpty && nameWords.isNotEmpty) {
      final (q2, used, glued2) = _leadingQuantity(nameWords);
      if (q2 != null && q2 > 0) {
        words = nameWords;
        quantity = q2;
        i = used;
        unit = glued2.isNotEmpty ? glued2 : consumeUnit();
        if (i < words.length && const {'de', 'do', 'da', 'dos', 'das'}.contains(normalize(words[i]))) {
          i++;
        }
        nameWords = words.sublist(i);
      }
    }

    var name = nameWords.join(' ').trim();
    // "Sal a gosto" / "a gosto de Gelo"
    if (re(r'\ba gosto\b').hasMatch(normalize(name))) {
      toTaste = true;
      name = name.replaceAll(re(r'\s*\b[aA] gosto\b\s*'), ' ').trim();
      name = name.replaceFirst(RegExp(r'^(de|do|da)\s+', caseSensitive: false), '');
    }
    if (name.isEmpty) name = original;
    // Nome em minúsculas para entrar no meio da frase ("Queijo ralado" -> "queijo ralado")
    if (name.length > 1 && name[0] != name[0].toLowerCase() && name[1] == name[1].toLowerCase()) {
      name = '${name[0].toLowerCase()}${name.substring(1)}';
    }

    // Palavras depois de "sem" ("manteiga sem sal") não identificam o item
    final normalizedName = tokens(normalize(name));
    final semIndex = normalizedName.indexOf('sem');
    final relevant = semIndex >= 0 ? normalizedName.sublist(0, semIndex) : normalizedName;
    final keyWords = relevant.where((w) => !stopwords.contains(w) && !_isNumeric(w)).toList();
    if (keyWords.isEmpty && relevant.isNotEmpty) keyWords.add(relevant.first);
    // Unidade que não é medida ("4 filés de tilápia") também identifica o item
    for (final w in tokens(normalize(unit))) {
      if (!_singleWordUnits.contains(w) &&
          !stopwords.contains(w) &&
          !w.startsWith('(') &&
          !keyWords.contains(w) &&
          !const {'cha', 'sopa', 'cafe', 'sobremesa', 'americano', 'gosto'}.contains(w)) {
        keyWords.add(w);
      }
    }

    return ParsedIngredient(
      original: original,
      quantity: quantity,
      unit: unit,
      name: name,
      keyWords: keyWords,
      toTaste: toTaste || (quantity != null && quantity <= 0),
    );
  }
}

class ParsedIngredient {
  final String original;
  final double? quantity;
  final String unit;
  final String name;

  /// Palavras normalizadas que identificam o ingrediente (a primeira é a principal).
  final List<String> keyWords;

  /// Ingrediente sem quantidade definida ("sal a gosto").
  final bool toTaste;

  const ParsedIngredient({
    required this.original,
    required this.quantity,
    required this.unit,
    required this.name,
    required this.keyWords,
    this.toTaste = false,
  });

  String get head => keyWords.isEmpty ? '' : keyWords.first;

  bool isWeak(String word) => RecipeLanguage.weakDescriptors.contains(word);

  bool get hasQuantity => quantity != null && quantity! > 0;

  static const Set<String> _masculineUnits = {
    'quilo', 'quilos', 'kg', 'litro', 'litros', 'l', 'lt', 'copo', 'copos',
    'pacote', 'pacotes', 'grama', 'gramas', 'g', 'gr', 'ml', 'mililitro',
    'mililitros', 'dente', 'dentes', 'tablete', 'tabletes', 'envelope', 'sache',
    'pote', 'vidro', 'cubo', 'talo', 'pedaco', 'maco', 'ramo', 'punhado', 'fio',
    'copinho', 'kilo', 'kilos',
  };

  // Unidade falada por extenso ("g" -> "gramas", "xícara (chá)" -> "xícara de chá")
  String _unitText(double q) {
    var u = unit.replaceAllMapped(
      RegExp(r'\((ch[aá]|sopa|caf[eé]|sobremesa)\)', caseSensitive: false),
      (m) => 'de ${m.group(1)}',
    );
    final spokenUnit = RecipeLanguage._spokenUnits[RecipeLanguage.normalize(u)];
    if (spokenUnit != null) u = q < 2 ? spokenUnit[0] : spokenUnit[1];
    return u;
  }

  bool get _masculine {
    final words = RecipeLanguage.tokens(RecipeLanguage.normalize(unit));
    return words.isNotEmpty && _masculineUnits.contains(words.first);
  }

  /// Quantidade + unidade + nome, pronto para ser falado.
  String get spoken {
    final q = quantity;
    if (q == null || q <= 0 || !q.isFinite) {
      if (toTaste || (q != null && q <= 0)) return '$name a gosto';
      return unit.isEmpty ? name : '$unit de $name';
    }
    final whole = q.floor();
    final fraction = q - whole;
    final half = (fraction - 0.5).abs() < 0.01;
    final quarter = (fraction - 0.25).abs() < 0.01;
    final threeQuarters = (fraction - 0.75).abs() < 0.01;
    final meia = _masculine ? 'meio' : 'meia';

    if (unit.isEmpty) {
      if (whole == 0 && half) return '$meia $name';
      return '${RecipeLanguage.formatNumber(q)} $name';
    }
    // Frações comuns ditas como na cozinha: "meia xícara", "2 xícaras e meia"
    if (whole == 0 && half) return '$meia ${_unitText(1)} de $name';
    if (whole == 0 && quarter) return 'um quarto de ${_unitText(1)} de $name';
    if (whole == 0 && threeQuarters) return 'três quartos de ${_unitText(1)} de $name';
    if (whole >= 1 && half) return '$whole ${_unitText(whole.toDouble())} e $meia de $name';
    return '${RecipeLanguage.formatNumber(q)} ${_unitText(q)} de $name';
  }
}
