// Modelos trocados entre a tela de detalhes, o interpretador local e o backend.

class RecipeAssistantModes {
  static const String ingredientes = 'ingredientes';
  static const String passos = 'passos';
}

// Uma fala do histórico recente da conversa
class RecipeAssistantTurn {
  final String role; // 'user' ou 'assistant'
  final String text;

  const RecipeAssistantTurn({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

// Estado da receita e da conversa no momento em que o usuário fala
class RecipeAssistantContext {
  final String title;
  final String? category;
  final List<String> ingredients;
  final List<String> instructions;
  final List<bool> ingredientChecked;
  final List<bool> instructionChecked;
  final int currentStepIndex;
  final int currentIngredientIndex;

  /// 'ingredientes', 'passos' ou null quando a tela não informou.
  final String? mode;
  final String lastResponse;

  /// Ação oferecida na última resposta com uma pergunta de sim/não.
  final String? pendingAction;
  final List<RecipeAssistantTurn> history;

  RecipeAssistantContext({
    required this.title,
    required this.ingredients,
    required this.instructions,
    List<bool>? ingredientChecked,
    List<bool>? instructionChecked,
    this.currentStepIndex = 0,
    this.currentIngredientIndex = 0,
    this.mode,
    this.lastResponse = '',
    this.pendingAction,
    this.history = const [],
    this.category,
  })  : ingredientChecked = _fit(ingredientChecked, ingredients.length),
        instructionChecked = _fit(instructionChecked, instructions.length);

  static List<bool> _fit(List<bool>? values, int length) {
    return List<bool>.generate(
      length,
      (i) => values != null && i < values.length ? values[i] : false,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'category': category,
        'ingredients': ingredients,
        'instructions': instructions,
        'ingredientChecked': ingredientChecked,
        'instructionChecked': instructionChecked,
        'currentStepIndex': currentStepIndex,
        'currentIngredientIndex': currentIngredientIndex,
        'mode': mode,
        'lastResponse': lastResponse,
        'pendingAction': pendingAction,
        'history': history.map((t) => t.toJson()).toList(),
      };
}

// Resultado da interpretação: o que falar e o que mudar na tela
class RecipeAssistantIntent {
  final String action;

  /// Passo atual depois da fala (índice começando em 0).
  final int stepIndex;
  final String responseText;
  final List<int> checkIngredients;
  final List<int> uncheckIngredients;
  final List<int> checkSteps;
  final List<int> uncheckSteps;

  /// Ingrediente que passa a ser o atual, quando muda.
  final int? ingredientIndex;

  /// Novo modo do assistente, quando muda.
  final String? mode;
  final bool stopAssistant;

  /// Ação a executar se o usuário responder "sim" na próxima fala.
  final String? pendingAction;

  /// Quão segura foi a interpretação local (0 a 1).
  final double confidence;

  /// 'local' ou 'backend'.
  final String source;

  const RecipeAssistantIntent({
    required this.action,
    required this.stepIndex,
    required this.responseText,
    this.checkIngredients = const [],
    this.uncheckIngredients = const [],
    this.checkSteps = const [],
    this.uncheckSteps = const [],
    this.ingredientIndex,
    this.mode,
    this.stopAssistant = false,
    this.pendingAction,
    this.confidence = 1.0,
    this.source = 'local',
  });
}
