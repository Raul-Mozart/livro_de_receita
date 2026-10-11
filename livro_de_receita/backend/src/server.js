// Inicia o servidor do assistente de receitas
const config = require('./config');
const { app } = require('./app');
const { resolveProvider } = require('./providers');

app.listen(config.port, () => {
  console.log(`Assistente de receitas ouvindo na porta ${config.port} (IA: ${resolveProvider() || 'nenhuma'})`);
  if (!config.appToken) {
    console.warn(
      'ATENÇÃO: ASSISTANT_APP_TOKEN não está definido. Qualquer pessoa com a URL pode usar o assistente e gastar a cota da chave.',
    );
  }
});
