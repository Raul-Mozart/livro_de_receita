# Firebase — configuração e testes locais

O app usa **Firebase Auth** (login por e-mail e senha) e **Cloud Firestore** (receitas). Enquanto o projeto
real não é criado, o app usa o projeto provisório `demo-livro-receitas`, que só existe nos **emuladores locais**.

## Planos e custos (dados oficiais, 2026-10)
- **Spark (grátis, sem cartão):** Firestore com 1 GiB armazenado, 50 mil leituras, 20 mil gravações e 20 mil
  exclusões por dia; Auth com 50 mil usuários ativos por mês. Passou da cota: o serviço para até o fim do mês.
- **Blaze (pago pelo uso):** necessário só para guardar fotos no Cloud Storage (etapa futura). Mantém as cotas
  grátis; alerta de orçamento avisa, mas não limita gasto.

## Rodar com os emuladores (sem conta no Google)
Requisitos: Node 20+ e **JDK 21+** (o JBR do Android Studio serve).

```powershell
cd firebase
npm install                       # uma vez
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
npm run emulators                 # Auth em :9099 e Firestore em :8080
```

Em outro terminal, na raiz do app:

```powershell
flutter run -d emulator-5554      # projeto demo-... liga os emuladores sozinho (Android usa 10.0.2.2)
# Celular físico na mesma rede: flutter run --dart-define=FIREBASE_EMULATOR_HOST=<IP do computador>
```

Testes das regras: `cd firebase; npm test`.

## Identificadores do app (registrar no Firebase)
- Android: `com.raulmozart.livro_de_receitas` · iOS/macOS: `com.raulmozart.livroDeReceitas`.
- Até 2026-10-15 o Android usava `com.example.lista_de_compras`: para o aparelho é **outro app**, com outro banco.

## Criar o projeto real (uma vez)
1. https://console.firebase.google.com → **Adicionar projeto** (o Google Analytics pode ficar desligado).
2. **Authentication → Método de login → E-mail/senha → Ativar.**
3. **Firestore Database → Criar banco de dados** → edição *Standard*, local `southamerica-east1 (São Paulo)`,
   modo de produção. (A cota grátis vale para o primeiro banco do projeto.)
4. No computador:
   ```powershell
   cd firebase
   npx firebase login                       # abre o navegador
   npx firebase use --add                   # escolha o projeto criado e o alias "default"
   npm run deploy:rules                     # publica firebase/firestore.rules
   cd ..
   dart pub global activate flutterfire_cli
   flutterfire configure                    # escolha o projeto e as plataformas (android, ios)
   ```
   O `flutterfire configure` reescreve `lib/firebase_options.dart` com o projeto real. A chave de API desse
   arquivo identifica o projeto (não é segredo); a proteção dos dados vem das regras do Firestore.
5. `flutter run` de novo: agora o app fala com a nuvem. Para voltar aos emuladores com o projeto real:
   `flutter run --dart-define=USE_FIREBASE_EMULATOR=true`.

## Trazer as receitas do app antigo (`com.example.lista_de_compras`)
O app novo só copia sozinho o `receitas.db` que está na **própria** pasta. Num aparelho com o app antigo, copie o banco
de um app para o outro antes de abrir o app novo (os dois precisam ser builds de depuração; o arquivo não sai do aparelho):

```powershell
adb -s <serial> install build\app\outputs\flutter-apk\app-debug.apk
adb -s <serial> shell "run-as com.example.lista_de_compras cat databases/receitas.db > /data/local/tmp/r.db"
adb -s <serial> shell "run-as com.raulmozart.livro_de_receitas sh -c 'mkdir -p databases && cp /data/local/tmp/r.db databases/receitas.db && chmod 700 databases && chmod 600 databases/receitas.db'"
adb -s <serial> shell rm /data/local/tmp/r.db
```

Depois: abrir o app novo, entrar na conta (com internet) e conferir a mensagem "N receitas deste aparelho foram
copiadas". Só então desinstalar o app antigo (desinstalar apaga o banco dele).

## Estrutura
- `firebase.json` / `.firebaserc` — configuração do Firebase CLI (emuladores, regras).
- `firebase/firestore.rules` — quem lê e grava o quê (manter os limites iguais aos de `receita_repository.dart`).
- `firebase/test/` — testes das regras no emulador.
- `lib/data/firebase_setup.dart` — inicialização, banco local sem limite de tamanho e emuladores.
