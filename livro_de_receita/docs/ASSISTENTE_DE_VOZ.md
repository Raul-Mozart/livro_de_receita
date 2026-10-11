# Assistente de voz

O assistente da tela de detalhes entende **fala livre** (sem comandos fixos) e responde sempre sobre a
receita aberta: ingredientes, quantidades, passos, tempo, temperatura e andamento do preparo.

## Como funciona

1. A fala é transcrita pelo `speech_to_text` (sempre em português do Brasil) e enviada para
   `RecipeAssistantService` (`lib/assistant/`).
2. O **interpretador local** (`local_recipe_interpreter.dart`) roda no próprio aparelho, sem internet.
   Ele identifica ingredientes citados (tolerando plural, gírias e erros de reconhecimento), números de
   passos, negações, perguntas de quantidade, tempo e temperatura, e usa o contexto da conversa.
   Todas as alternativas do reconhecimento de voz são consideradas.
3. Falas bem entendidas localmente respondem na hora. Perguntas abertas (substituições, técnicas,
   frases confusas) vão para o **backend de IA**, se estiver configurado.
4. Sem backend, ou com ele fora do ar, o app continua funcionando só com o interpretador local.

A tela aplica o resultado: marca/desmarca ingredientes e passos, muda o passo atual e fala a resposta.

## Configuração do app

Copie `assets/config/app.env.example` para `assets/config/app.env` e preencha:

    ASSISTANT_BACKEND_URL=http://10.0.2.2:3001/api/assistant/interpret
    ASSISTANT_APP_TOKEN=<mesmo valor do backend/.env>

- Emulador Android: `10.0.2.2` aponta para o computador.
- Celular físico: use o IP do computador na mesma rede.
- HTTP sem TLS só é liberado em builds de debug; em produção, publique o backend com **HTTPS**.
- O `app.env` não vai para o git. Sem ele o assistente funciona só no modo local.

## Backend

Estrutura (`backend/src/`):

| Arquivo | Função |
|---|---|
| `server.js` | Inicia o servidor |
| `app.js` | Rotas (`/health` e `/api/assistant/interpret`) |
| `security.js` | Token do app, limite por aparelho e cota diária de IA |
| `contract.js` | Validação da entrada e da resposta da IA |
| `prompt.js` | Instruções e contexto enviados à IA |
| `providers.js` | Chamadas ao Gemini ou à OpenAI |
| `config.js` | Variáveis de ambiente |

Para rodar:

1. Entre na pasta `backend` e instale as dependências: `npm install`
2. Copie `backend/.env.example` para `backend/.env` e preencha `GEMINI_API_KEY` (ou `OPENAI_API_KEY`)
   e `ASSISTANT_APP_TOKEN`
3. Inicie: `npm start`
4. Confira em `http://localhost:3001/health` o provedor ativo e se o token está sendo exigido

Sem chave de IA, o backend responde `503` e o app usa apenas o interpretador local.

## Proteções do backend

Como o app pode ser usado por várias pessoas, o backend protege a chave da IA:

- **Token do app** (`ASSISTANT_APP_TOKEN`): pedidos sem o cabeçalho `x-assistant-token` correto recebem
  `401`. O token fica no app, então dificulta o uso por terceiros, mas não substitui um login.
- **Limite por aparelho**: `RATE_LIMIT_PER_MINUTE` (padrão 20) e `RATE_LIMIT_PER_DAY` (padrão 300)
  pedidos por IP. Acima disso, `429`.
- **Cota diária de IA** (`AI_DAILY_LIMIT`, padrão 2000 chamadas): protege o custo da chave.
- **Atrás de proxy/hospedagem**: defina `TRUST_PROXY=1` para os limites usarem o IP real do usuário.

Quando recebe `401`, `429` ou erro do servidor, o app passa alguns minutos só no modo local e depois
volta a consultar a IA.

## Diagnóstico

Ao rodar com `flutter run`, o console mostra cada fala interpretada:

    [assistente] ouvi: [já peguei o arroz] -> "já peguei o arroz" = check_ingredients (local)

Se o reconhecimento vier em inglês, adicione **Português (Brasil)** na entrada de voz do Google
(Configurações → Sistema → Idiomas → Entrada de voz).

## Observação sobre o plugin de voz

`third_party/speech_to_text` é uma cópia do plugin com um ajuste no Android: o idioma pedido é sempre
enviado ao reconhecedor. Sem isso, o Google usa o idioma da digitação por voz do aparelho (muitas vezes
inglês). Ao atualizar o plugin, reaplique esse ajuste.
