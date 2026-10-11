// Proteções do backend: token do app, limite de pedidos por aparelho e cota
// diária de chamadas à IA (para a conta da chave não disparar)
const crypto = require('crypto');
const config = require('./config');

const MINUTE = 60 * 1000;
const DAY = 24 * 60 * MINUTE;

// Compara em tempo constante para não vazar o token pelo tempo de resposta
function sameToken(received, expected) {
  const a = crypto.createHash('sha256').update(String(received)).digest();
  const b = crypto.createHash('sha256').update(String(expected)).digest();
  return crypto.timingSafeEqual(a, b);
}

function requireAppToken(req, res, next) {
  if (!config.appToken) return next();
  if (!sameToken(req.get('x-assistant-token') || '', config.appToken)) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  return next();
}

// Contadores em memória por cliente (IP): janela de 1 minuto e de 1 dia
const clients = new Map();

function rateLimit(req, res, next) {
  const now = Date.now();
  const key = req.ip || 'desconhecido';
  let client = clients.get(key);
  if (!client) {
    client = { minuteStart: now, minuteCount: 0, dayStart: now, dayCount: 0 };
    clients.set(key, client);
  }
  if (now - client.minuteStart >= MINUTE) {
    client.minuteStart = now;
    client.minuteCount = 0;
  }
  if (now - client.dayStart >= DAY) {
    client.dayStart = now;
    client.dayCount = 0;
  }
  if (client.minuteCount >= config.rateLimitPerMinute || client.dayCount >= config.rateLimitPerDay) {
    const waitMs = client.dayCount >= config.rateLimitPerDay
      ? DAY - (now - client.dayStart)
      : MINUTE - (now - client.minuteStart);
    res.set('Retry-After', String(Math.ceil(waitMs / 1000)));
    return res.status(429).json({ error: 'rate_limited' });
  }
  client.minuteCount++;
  client.dayCount++;
  return next();
}

// Remove de hora em hora os clientes que não aparecem há mais de um dia
setInterval(() => {
  const now = Date.now();
  for (const [key, client] of clients) {
    if (now - client.dayStart >= DAY) clients.delete(key);
  }
}, 60 * MINUTE).unref();

// Cota diária global de chamadas ao provedor de IA
let quotaDay = new Date().toISOString().slice(0, 10);
let quotaUsed = 0;

function consumeAiQuota() {
  const today = new Date().toISOString().slice(0, 10);
  if (today !== quotaDay) {
    quotaDay = today;
    quotaUsed = 0;
  }
  if (quotaUsed >= config.aiDailyLimit) return false;
  quotaUsed++;
  return true;
}

module.exports = { requireAppToken, rateLimit, consumeAiQuota };
