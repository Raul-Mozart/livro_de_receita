// Configuração do backend lida das variáveis de ambiente (arquivo backend/.env)
const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

const number = (value, fallback) => {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};

module.exports = {
  port: number(process.env.PORT, 3001),

  // Provedor de IA (a chave fica só no servidor)
  aiProvider: (process.env.AI_PROVIDER || '').trim().toLowerCase(),
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  openaiApiKey: process.env.OPENAI_API_KEY || '',
  geminiModel: process.env.GEMINI_MODEL || 'gemini-3.5-flash-lite',
  openaiModel: process.env.OPENAI_MODEL || 'gpt-4o-mini',
  providerTimeoutMs: number(process.env.PROVIDER_TIMEOUT_MS, 7000),

  // Proteção: token do app e limites de uso
  appToken: (process.env.ASSISTANT_APP_TOKEN || '').trim(),
  rateLimitPerMinute: number(process.env.RATE_LIMIT_PER_MINUTE, 20),
  rateLimitPerDay: number(process.env.RATE_LIMIT_PER_DAY, 300),
  aiDailyLimit: number(process.env.AI_DAILY_LIMIT, 2000),
  // Atrás de proxy/hospedagem (Render, Railway, nginx...), use TRUST_PROXY=1
  trustProxy: process.env.TRUST_PROXY || '',
};
