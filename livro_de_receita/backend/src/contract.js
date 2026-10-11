// Contrato entre o app e o backend: validação da entrada e da resposta da IA

// Ações que o app sabe executar quando o usuário responde "sim"
const CONFIRMABLE_ACTIONS = [
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
];

const ACTIONS = [
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
];

const asString = (value, max = 500) => String(value ?? '').slice(0, max);
const asStringList = (value, maxItems = 60, maxLength = 400) =>
  Array.isArray(value) ? value.slice(0, maxItems).map((item) => asString(item, maxLength)) : [];
const asBoolList = (value, length) =>
  Array.from({ length }, (_, i) => Array.isArray(value) && value[i] === true);
const asIndex = (value, fallback = 0) => (Number.isInteger(value) ? value : fallback);

// Limita tamanhos para não repassar conteúdo arbitrário ao provedor
function sanitizeRequest(body) {
  const ingredients = asStringList(body.ingredients, 60, 400);
  const instructions = asStringList(body.instructions, 60, 2000);
  const history = Array.isArray(body.history)
    ? body.history.slice(-12).map((turn) => ({
        role: turn && turn.role === 'assistant' ? 'assistant' : 'user',
        text: asString(turn && turn.text, 600),
      }))
    : [];
  return {
    transcript: asString(body.transcript, 500).trim(),
    title: asString(body.title, 200),
    category: body.category ? asString(body.category, 100) : '',
    ingredients,
    instructions,
    ingredientChecked: asBoolList(body.ingredientChecked, ingredients.length),
    instructionChecked: asBoolList(body.instructionChecked, instructions.length),
    currentStepIndex: Math.min(Math.max(asIndex(body.currentStepIndex), 0), Math.max(instructions.length - 1, 0)),
    currentIngredientIndex: Math.min(Math.max(asIndex(body.currentIngredientIndex), 0), Math.max(ingredients.length - 1, 0)),
    mode: body.mode === 'passos' || body.mode === 'ingredientes' ? body.mode : 'desconhecido',
    lastResponse: asString(body.lastResponse, 800),
    pendingAction: ACTIONS.includes(body.pendingAction) ? body.pendingAction : null,
    history,
  };
}

function parseModelJson(content) {
  const clean = String(content).replace(/```json|```/g, '').trim();
  try {
    return JSON.parse(clean);
  } catch (_) {
    const start = clean.indexOf('{');
    const end = clean.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(clean.slice(start, end + 1));
    }
    throw new Error('invalid json from model');
  }
}

// Garante que a resposta do modelo respeita o contrato e os limites da receita
function normalizeModelOutput(parsed, req) {
  const stepCount = req.instructions.length;
  const ingredientCount = req.ingredients.length;
  const toInt = (value) => {
    if (Number.isInteger(value)) return value;
    if (typeof value === 'string' && /^-?\d+$/.test(value.trim())) return Number.parseInt(value, 10);
    return null;
  };
  // Sem stepIndex do modelo, envia null para o app aplicar o padrão de cada ação
  const clampStep = (value) => {
    const n = toInt(value);
    if (n === null) return null;
    if (!stepCount) return 0;
    return Math.min(Math.max(n, 0), stepCount - 1);
  };
  const indexList = (value, length) =>
    Array.isArray(value)
      ? [...new Set(value.filter((n) => Number.isInteger(n) && n >= 0 && n < length))]
      : [];

  const action = ACTIONS.includes(parsed.action) ? parsed.action : 'general';
  const longAnswer = action === 'read_all_steps' || action === 'ingredients';
  let responseText = String(parsed.responseText || '')
    .replace(/[*_#`>]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  // Respostas muito longas travam o TTS; corta no fim de uma frase
  const maxLength = longAnswer ? 6000 : 1500;
  if (responseText.length > maxLength) {
    const cut = responseText.slice(0, maxLength);
    const lastSentence = Math.max(cut.lastIndexOf('. '), cut.lastIndexOf('! '), cut.lastIndexOf('? '));
    responseText = lastSentence > maxLength / 2 ? cut.slice(0, lastSentence + 1) : cut;
  }
  const ingredientIndex = toInt(parsed.ingredientIndex);

  return {
    action,
    stepIndex: clampStep(parsed.stepIndex),
    ingredientIndex:
      ingredientIndex !== null && ingredientIndex >= 0 && ingredientIndex < ingredientCount ? ingredientIndex : null,
    checkIngredients: indexList(parsed.checkIngredients, ingredientCount),
    uncheckIngredients: indexList(parsed.uncheckIngredients, ingredientCount),
    checkSteps: indexList(parsed.checkSteps, stepCount),
    uncheckSteps: indexList(parsed.uncheckSteps, stepCount),
    mode: parsed.mode === 'passos' || parsed.mode === 'ingredientes' ? parsed.mode : null,
    stopAssistant: parsed.stopAssistant === true || action === 'stop_assistant',
    pendingAction: CONFIRMABLE_ACTIONS.includes(parsed.pendingAction) ? parsed.pendingAction : null,
    responseText,
  };
}

module.exports = { ACTIONS, CONFIRMABLE_ACTIONS, sanitizeRequest, parseModelJson, normalizeModelOutput };
