# Firebase — configuração e testes locais

O app usa **Firebase Auth** (login por e-mail e senha) e **Cloud Firestore** (receitas) no projeto real
`livro-de-receitas-97927` (plano Spark; Firestore *Standard* em `southamerica-east1`; criado em 2026-10-15).
Console: https://console.firebase.google.com/project/livro-de-receitas-97927/overview

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
$env:Path = "$env:JAVA_HOME\bin;$env:Path"   # o firebase-tools usa o java do PATH
npm run emulators                 # Auth em :9099 e Firestore em :8080
```

Em outro terminal, na raiz do app:

```powershell
flutter run -d emulator-5554 --dart-define=USE_FIREBASE_EMULATOR=true   # Android usa 10.0.2.2
# Celular físico na mesma rede: acrescente --dart-define=FIREBASE_EMULATOR_HOST=<IP do computador>
```

O `npm run emulators` sobe o projeto `demo-livro-receitas`; o app pede o ID real e o emulador só avisa
("Multiple projectIds..."). Para as regras valerem no mesmo ID do app, suba com
`npx firebase emulators:start --project livro-de-receitas-97927` (só emuladores; não toca a nuvem).

Testes das regras: `cd firebase; npm test` (sempre no `demo-livro-receitas`).

## Identificadores do app (registrar no Firebase)
- Android: `com.raulmozart.livro_de_receitas` · iOS/macOS: `com.raulmozart.livroDeReceitas`.
- Até 2026-10-15 o Android usava `com.example.lista_de_compras`: para o aparelho é **outro app**, com outro banco.

## Projeto real (feito em 2026-10-15)
1. Console: projeto criado, **Authentication → E-mail/senha** ativo, **Firestore** *Standard* em
   `southamerica-east1`, modo de produção. Apps registrados: Android, iOS e web (ids em `firebase.json`).
2. Login do Firebase CLI (o `firebase-tools` fica só em `firebase/node_modules`, então sempre com `npx`):
   ```powershell
   cd firebase
   npx firebase login                       # mostra um link; o navegador termina com um código
   npx firebase login <código>              # conclui o login com o código do navegador
   ```
3. Publicar as regras depois de mudar `firebase/firestore.rules` (o `.firebaserc` já aponta para o projeto real):
   `cd firebase; npm test; npm run deploy:rules`.
4. Regerar a configuração do app (app novo ou plataforma nova):
   ```powershell
   $env:Path = "$env:LOCALAPPDATA\Pub\Cache\bin;$PWD\firebase\node_modules\.bin;$env:Path"
   flutterfire configure --project=livro-de-receitas-97927 --platforms=android,ios,web `
     --android-package-name=com.raulmozart.livro_de_receitas --ios-bundle-id=com.raulmozart.livroDeReceitas --yes
   ```
   Reescreve `lib/firebase_options.dart`, `android/app/google-services.json` e a seção `flutter` do `firebase.json`.
   As chaves de API desses arquivos identificam o projeto (não são segredo); a proteção vem das regras do Firestore.

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
- `firebase.json` / `.firebaserc` — configuração do Firebase CLI (emuladores, regras, apps do FlutterFire).
- `lib/firebase_options.dart` + `android/app/google-services.json` — configuração gerada pelo `flutterfire configure`.
- `firebase/firestore.rules` — quem lê e grava o quê (manter os limites iguais aos de `receita_repository.dart`).
- `firebase/test/` — testes das regras no emulador.
- `lib/data/firebase_setup.dart` — inicialização, banco local sem limite de tamanho e emuladores.
