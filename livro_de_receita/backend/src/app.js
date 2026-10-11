// Rotas do backend do assistente de receitas
const express = require('express');
const config = require('./config');
const { requireAppToken, rateLimit, consumeAiQuota } = require('./security');
const { sanitizeRequest, parseModelJson, normalizeModelOutput } = require('./contract');
const { buildUserPrompt } = require('./prompt');
const { resolveProvider, modelFor, askModel } = require('./providers');

const app = express();
app.disable('x-powered-by');
if (config.trustProxy) {
  app.set('trust proxy', /^\d+$/.test(config.trustProxy) ? Number(config.trustProxy) : config.trustProxy);
}
app.use(express.json({ limit: '64kb' }));

app.get('/health', (_req, res) => {
  const provider = resolveProvider();
  res.json({
    ok: true,
    provider: provider || 'none',
    model: modelFor(provider),
    tokenRequired: Boolean(config.appToken),
  });
});

app.post('/api/assistant/interpret', requireAppToken, rateLimit, async (req, res) => {
  const request = sanitizeRequest(req.body || {});
  if (!request.transcript) {
    return res.status(400).json({ error: 'empty_transcript' });
  }

  const provider = resolveProvider();
  if (!provider) {
    // Sem chave configurada: o app usa o interpretador local
    return res.status(503).json({ error: 'no_ai_provider_configured' });
  }
  if (!consumeAiQuota()) {
    // Cota diária atingida: o app segue com o interpretador local
    return res.status(429).json({ error: 'daily_quota_exceeded' });
  }

  try {
    const content = await askModel(provider, buildUserPrompt(request));
    const output = normalizeModelOutput(parseModelJson(content), request);
    if (!output.responseText) {
      return res.status(502).json({ error: 'empty_model_response' });
    }
    return res.status(200).json(output);
  } catch (error) {
    console.error(`[assistant] ${provider} falhou:`, error.message);
    // Erro no provedor: o app cai para o interpretador local
    return res.status(502).json({ error: 'ai_provider_failed' });
  }
});

// JSON inválido ou corpo grande demais
app.use((error, _req, res, _next) => {
  const status = error.status || error.statusCode || 500;
  res.status(status >= 400 && status < 500 ? status : 500).json({ error: 'bad_request' });
});

module.exports = { app };
