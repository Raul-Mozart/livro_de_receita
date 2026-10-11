// Chamadas aos provedores de IA (Gemini ou OpenAI)
const config = require('./config');
const { SYSTEM_PROMPT, GEMINI_RESPONSE_SCHEMA } = require('./prompt');

// Provedor escolhido por AI_PROVIDER ou pela chave disponível
function resolveProvider() {
  if (config.aiProvider === 'gemini' && config.geminiApiKey) return 'gemini';
  if (config.aiProvider === 'openai' && config.openaiApiKey) return 'openai';
  if (config.geminiApiKey) return 'gemini';
  if (config.openaiApiKey) return 'openai';
  return null;
}

function modelFor(provider) {
  if (provider === 'gemini') return config.geminiModel;
  if (provider === 'openai') return config.openaiModel;
  return null;
}

async function fetchWithTimeout(url, options) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.providerTimeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function callGemini(userPrompt) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(config.geminiModel)}:generateContent`;
  const buildBody = (withSchema) => ({
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
    generationConfig: {
      responseMimeType: 'application/json',
      ...(withSchema ? { responseSchema: GEMINI_RESPONSE_SCHEMA } : {}),
      maxOutputTokens: 800,
    },
  });
  const send = (withSchema) =>
    fetchWithTimeout(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': config.geminiApiKey },
      body: JSON.stringify(buildBody(withSchema)),
    });

  let response = await send(true);
  // Alguns modelos não aceitam o esquema: tenta de novo só com JSON
  if (response.status === 400) {
    response = await send(false);
  }
  if (!response.ok) {
    throw new Error(`gemini ${response.status}: ${(await response.text()).slice(0, 300)}`);
  }
  const data = await response.json();
  const parts = data?.candidates?.[0]?.content?.parts || [];
  return parts.map((part) => part.text || '').join('');
}

async function callOpenAI(userPrompt) {
  const response = await fetchWithTimeout('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${config.openaiApiKey}`,
    },
    body: JSON.stringify({
      model: config.openaiModel,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userPrompt },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 800,
    }),
  });
  if (!response.ok) {
    throw new Error(`openai ${response.status}: ${(await response.text()).slice(0, 300)}`);
  }
  const data = await response.json();
  return data?.choices?.[0]?.message?.content ?? '';
}

async function askModel(provider, userPrompt) {
  return provider === 'gemini' ? callGemini(userPrompt) : callOpenAI(userPrompt);
}

module.exports = { resolveProvider, modelFor, askModel };
