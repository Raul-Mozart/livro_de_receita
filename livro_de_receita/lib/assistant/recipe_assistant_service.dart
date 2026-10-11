import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:http/http.dart' as http;

import 'package:livro_de_receita/assistant/local_recipe_interpreter.dart';
import 'package:livro_de_receita/assistant/recipe_assistant_models.dart';

export 'recipe_assistant_models.dart';

class RecipeAssistantService {
  static final http.Client _client = http.Client();

  // Abaixo dessa confiança local, a fala é enviada para a IA do backend
  static const double backendConfidenceThreshold = 0.75;
  static const Duration backendTimeout = Duration(seconds: 8);
  static const Duration _backendCooldown = Duration(seconds: 45);

  DateTime? _backendUnavailableUntil;

  static const Set<String> knownActions = {
    'start_prep',
    'check_ingredients',
    'uncheck_ingredients',
    'ingredients',
    'missing_ingredients',
    'next_ingredient',
    'ingredient_info',
    'current_step',
    'next_step',
    'complete_step',
    'previous_step',
    'go_to_step',
    'repeat_step',
    'repeat_last',
    'uncheck_steps',
    'read_all_steps',
    'recipe_info',
    'explain_step',
    'help',
    'smalltalk',
    'decline',
    'stop_assistant',
    'general',
  };

  // Ações que um "sim" do usuário consegue executar localmente
  static const Set<String> confirmableActions = {
    'start_prep',
    'next_step',
    'previous_step',
    'current_step',
    'repeat_step',
    'ingredients',
    'missing_ingredients',
    'next_ingredient',
    'read_all_steps',
    'explain_step',
    'stop_assistant',
  };

  static const Set<String> _stepActions = {
    'start_prep',
    'current_step',
    'next_step',
    'complete_step',
    'previous_step',
    'go_to_step',
    'repeat_step',
    'uncheck_steps',
  };

  static String _readEnv(String key) {
    try {
      final fromDotEnv = dotenv.dotenv.env[key];
      if (fromDotEnv != null && fromDotEnv.isNotEmpty) {
        return fromDotEnv;
      }
    } catch (_) {
      // Ignora acesso antes do carregamento do arquivo .env.
    }

    switch (key) {
      case 'ASSISTANT_BACKEND_URL':
        return const String.fromEnvironment(
          'ASSISTANT_BACKEND_URL',
          defaultValue: '',
        );
      case 'ASSISTANT_APP_TOKEN':
        return const String.fromEnvironment(
          'ASSISTANT_APP_TOKEN',
          defaultValue: '',
        );
      default:
        return '';
    }
  }

  static String resolveBackendUrl() {
    return _readEnv('ASSISTANT_BACKEND_URL').trim();
  }

  /// Token que identifica o app para o backend (cabeçalho x-assistant-token).
  static String resolveAppToken() {
    return _readEnv('ASSISTANT_APP_TOKEN').trim();
  }

  static RecipeAssistantContext buildContext({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
    required int currentStepIndex,
    List<bool>? ingredientChecked,
    List<bool>? instructionChecked,
    int currentIngredientIndex = 0,
    String? mode,
    String lastResponse = '',
    String? pendingAction,
    List<RecipeAssistantTurn> history = const [],
    String? category,
  }) {
    return RecipeAssistantContext(
      title: title,
      category: category,
      ingredients: ingredients,
      instructions: instructions,
      ingredientChecked: ingredientChecked,
      instructionChecked: instructionChecked,
      currentStepIndex: currentStepIndex,
      currentIngredientIndex: currentIngredientIndex,
      mode: mode,
      lastResponse: lastResponse,
      pendingAction: pendingAction,
      history: history,
    );
  }

  /// Frase de boas-vindas ao ativar o assistente.
  static String welcomeMessage(RecipeAssistantContext context) =>
      LocalRecipeInterpreter(context).welcomeMessage();

  /// Prepara o interpretador (compila as expressões) enquanto a boas-vindas
  /// é falada, para a primeira resposta do usuário sair sem atraso.
  static void warmUp(RecipeAssistantContext context) {
    try {
      final interpreter = LocalRecipeInterpreter(context);
      for (final phrase in const ['peguei', 'qual o próximo passo', 'quanto tempo no forno', 'repete']) {
        interpreter.interpret(phrase);
      }
    } catch (_) {
      // Aquecimento é opcional
    }
  }

  /// Ação oferecida na frase de boas-vindas, se houver.
  static String? welcomePendingAction(RecipeAssistantContext context) =>
      LocalRecipeInterpreter(context).welcomePendingAction();

  /// Interpreta as alternativas do reconhecimento de voz (a mais provável
  /// primeiro) e usa a primeira que o interpretador local entende bem; se
  /// nenhuma for clara, segue com a mais provável (que pode ir para a IA).
  /// Retorna a transcrição usada e o resultado.
  Future<(String, RecipeAssistantIntent)> interpretAlternatives({
    required List<String> transcripts,
    required RecipeAssistantContext context,
  }) async {
    final options = transcripts.where((t) => t.trim().isNotEmpty).take(5).toList();
    if (options.isEmpty) {
      return ('', await interpretWithContext(transcript: '', context: context));
    }
    for (final option in options) {
      try {
        final local = LocalRecipeInterpreter(context).interpret(option);
        if (local.confidence >= backendConfidenceThreshold) return (option, local);
      } catch (_) {
        // tenta a próxima alternativa
      }
    }
    return (options.first, await interpretWithContext(transcript: options.first, context: context));
  }

  /// Interpreta uma fala: modo local primeiro; se a confiança for baixa, IA do backend.
  Future<RecipeAssistantIntent> interpretWithContext({
    required String transcript,
    required RecipeAssistantContext context,
  }) async {
    RecipeAssistantIntent fallback;
    try {
      fallback = LocalRecipeInterpreter(context).interpret(transcript);
    } catch (_) {
      // Falha inesperada no interpretador local: ainda tenta a IA do backend
      fallback = RecipeAssistantIntent(
        action: 'general',
        stepIndex: _clampIndex(context.currentStepIndex, context.instructions.length),
        responseText: 'Desculpe, não consegui entender. Pode repetir de outro jeito?',
        confidence: 0,
      );
    }

    // Falas bem entendidas localmente respondem na hora; perguntas abertas
    // (substituições, técnicas, frases confusas) vão para a IA do backend.
    if (fallback.confidence >= backendConfidenceThreshold) {
      return fallback;
    }

    final backendUrl = resolveBackendUrl();
    final unavailableUntil = _backendUnavailableUntil;
    final inCooldown =
        unavailableUntil != null && DateTime.now().isBefore(unavailableUntil);
    if (backendUrl.isNotEmpty && !inCooldown) {
      try {
        final backendIntent = await _callBackend(
          backendUrl: backendUrl,
          transcript: transcript,
          context: context,
          fallback: fallback,
        ).timeout(backendTimeout);
        if (backendIntent != null) {
          _backendUnavailableUntil = null;
          return backendIntent;
        }
      } on _BackendUnavailable catch (e) {
        // Sem chave de IA (503), token recusado (401/403) ou cota esgotada (429):
        // não adianta tentar logo de novo; segue no modo local por um tempo
        final longPause = e.statusCode == 503 || e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 429;
        _backendUnavailableUntil = DateTime.now().add(
          longPause ? const Duration(minutes: 5) : _backendCooldown,
        );
      } catch (_) {
        // Sem conexão, tempo esgotado ou servidor fora do ar: evita novas esperas por um tempo
        _backendUnavailableUntil = DateTime.now().add(_backendCooldown);
      }
    }

    return fallback;
  }

  static int _clampIndex(int index, int length) {
    if (length == 0) return 0;
    if (index < 0) return 0;
    if (index >= length) return length - 1;
    return index;
  }

  Future<RecipeAssistantIntent?> _callBackend({
    required String backendUrl,
    required String transcript,
    required RecipeAssistantContext context,
    required RecipeAssistantIntent fallback,
  }) async {
    final requestBody = jsonEncode({
      'transcript': transcript,
      ...context.toJson(),
    });

    final token = resolveAppToken();
    final response = await _client.post(
      Uri.parse(backendUrl.trim()),
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'x-assistant-token': token,
      },
      body: requestBody,
    );

    // 401 = token errado, 429 = limite de uso atingido, 5xx = servidor/IA indisponível
    if (response.statusCode >= 500 ||
        response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 429) {
      throw _BackendUnavailable(response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return _intentFromBackendJson(decoded, context: context, fallback: fallback);
  }

  /// Valida a resposta da IA e completa os efeitos implícitos de cada ação.
  static RecipeAssistantIntent? _intentFromBackendJson(
    Map<String, dynamic> json, {
    required RecipeAssistantContext context,
    required RecipeAssistantIntent fallback,
  }) {
    final ingredientCount = context.ingredients.length;
    final stepCount = context.instructions.length;
    final currentStep = _clampIndex(context.currentStepIndex, stepCount);

    var action = (json['action'] ?? 'general').toString().trim();
    if (!knownActions.contains(action)) action = 'general';

    final responseText = _cleanSpeech((json['responseText'] ?? '').toString());
    if (responseText.isEmpty) return null;

    int? asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    List<int> indexes(dynamic value, int length) {
      if (value is! List) return const [];
      final result = <int>[];
      for (final item in value) {
        final i = asInt(item);
        if (i != null && i >= 0 && i < length && !result.contains(i)) {
          result.add(i);
        }
      }
      return result;
    }

    final rawStep = asInt(json['stepIndex']);
    var stepIndex =
        rawStep == null ? currentStep : _clampIndex(rawStep, stepCount);
    var checkIngredients = indexes(json['checkIngredients'], ingredientCount);
    final uncheckIngredients =
        indexes(json['uncheckIngredients'], ingredientCount);
    var checkSteps = indexes(json['checkSteps'], stepCount);
    final uncheckSteps = indexes(json['uncheckSteps'], stepCount);

    var mode = json['mode']?.toString();
    if (mode != RecipeAssistantModes.ingredientes &&
        mode != RecipeAssistantModes.passos) {
      mode = null;
    }
    if (mode == null && _stepActions.contains(action)) {
      mode = RecipeAssistantModes.passos;
    }

    // Efeitos que a IA pode ter deixado implícitos
    if (action == 'start_prep') {
      if (checkIngredients.isEmpty) {
        checkIngredients = [
          for (var i = 0; i < ingredientCount; i++)
            if (!context.ingredientChecked[i]) i,
        ];
      }
      if (rawStep == null) stepIndex = 0;
    }
    if (action == 'complete_step' && checkSteps.isEmpty && stepCount > 0) {
      checkSteps = [currentStep];
      if (rawStep == null) {
        stepIndex = _clampIndex(currentStep + 1, stepCount);
      }
    }

    var pendingAction = json['pendingAction']?.toString();
    if (pendingAction != null && !confirmableActions.contains(pendingAction)) {
      pendingAction = null;
    }

    var ingredientIndex = asInt(json['ingredientIndex']);
    // Sem índice informado: o ingrediente atual passa a ser o primeiro ainda pendente
    if ((ingredientIndex == null || ingredientIndex < 0 || ingredientIndex >= ingredientCount) &&
        const {'check_ingredients', 'uncheck_ingredients', 'next_ingredient', 'missing_ingredients'}.contains(action)) {
      final after = List<bool>.from(context.ingredientChecked);
      for (final i in checkIngredients) {
        after[i] = true;
      }
      for (final i in uncheckIngredients) {
        after[i] = false;
      }
      final firstPending = uncheckIngredients.isNotEmpty ? uncheckIngredients.first : after.indexOf(false);
      ingredientIndex = firstPending >= 0 ? firstPending : null;
    }

    return RecipeAssistantIntent(
      action: action,
      stepIndex: stepIndex,
      responseText: responseText,
      checkIngredients: checkIngredients,
      uncheckIngredients: uncheckIngredients,
      checkSteps: checkSteps,
      uncheckSteps: uncheckSteps,
      ingredientIndex: ingredientIndex != null &&
              ingredientIndex >= 0 &&
              ingredientIndex < ingredientCount
          ? ingredientIndex
          : null,
      mode: mode,
      stopAssistant: json['stopAssistant'] == true || action == 'stop_assistant',
      pendingAction: pendingAction,
      confidence: 1.0,
      source: 'backend',
    );
  }

  // Remove marcações que o TTS leria em voz alta e limita o tamanho
  static String _cleanSpeech(String text, {int maxLength = 6000}) {
    var clean = text
        .replaceAll(RegExp(r'[*_#`>]+'), ' ')
        .replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length > maxLength) {
      final cut = clean.substring(0, maxLength);
      final lastSentence = cut.lastIndexOf(RegExp(r'[.!?]\s'));
      clean = lastSentence > maxLength ~/ 2 ? cut.substring(0, lastSentence + 1) : cut;
    }
    return clean;
  }
}

// Backend respondeu com erro de servidor (5xx)
class _BackendUnavailable implements Exception {
  final int statusCode;

  _BackendUnavailable(this.statusCode);
}
