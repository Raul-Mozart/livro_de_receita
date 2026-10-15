# CLAUDE.md — Projeto Livro de Receitas

> Contexto deste projeto (o Claude Code carrega só ao trabalhar nesta pasta). Regras gerais e protocolos: `../../CLAUDE.md`.
> Limite: 60 linhas. Aqui fica o que é estável; estado da sessão e próximos passos ficam em `../../.harness/STATE.md`,
> detalhes de decisões e incidentes em `../../.harness/memory/` (ADR/cards).

## Objetivo
- Livro de receitas pessoal: cadastrar (com foto, importar texto), ver por categoria, acompanhar o preparo e cozinhar
  com assistente de voz (fala livre; IA opcional via `backend/`).
- Receitas na nuvem por usuário (Firebase), funcionando sem internet (A-008, ADR-015). Fotos ainda locais (T-041).

## Stack
- Flutter 3.47 / Dart 3.x, Material. Pacote `livro_de_receita`; id Android `com.example.lista_de_compras` (sobra; D-008).
- Dados: `firebase_core`, `firebase_auth`, `cloud_firestore`; `sqflite` só para migrar o banco antigo (D-009).
  Dev: `fake_cloud_firestore`. Dependência nova → justificar em ADR (regra 04).
- Voz: `speech_to_text` (cópia ajustada em `third_party/`), `flutter_tts`; `backend/` Node guarda a chave da IA.

## Comandos (Flutter em `C:\src\flutter\bin`, fora do PATH do Git Bash)
- `flutter pub get` · `flutter test` · `flutter analyze` · `flutter run -d emulator-5554`.
- Emuladores Firebase (JDK 21+; o `java` do PATH é 1.8): `cd firebase; $env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'; npm run emulators`.
- Regras do Firestore: `cd firebase; npm test` (não rodar dois `emulators:*` ao mesmo tempo: portas 8080/9099/4400).
- Projeto real: `docs/FIREBASE.md` (`flutterfire configure` reescreve `lib/firebase_options.dart`; hoje é o demo).

## Estrutura
- `lib/data/firebase_setup.dart` init + banco local ilimitado + emulador (`demo-*` liga sozinho; Android = 10.0.2.2).
- `lib/data/receita_repository.dart` — `users/{uid}/receitas/{id}`; ingredientes/passos dentro do documento;
  `ReceitaRepository.atual` (definido no login) substitui os antigos DAOs estáticos. Limites = `firebase/firestore.rules`.
- `lib/data/auth_service.dart` (interface + Firebase), `lib/widgets/auth_gate.dart`, `lib/pages/login_page.dart`.
- `lib/data/migracao_sqlite.dart` — copia `receitas.db` uma vez (marca `migracao_firestore.json`; IDs `local-<id>-<ms>`).
- `lib/models/categoria.dart` — catálogo fixo (1 Salgados, 2 Doces, 3 Bebidas; ordem alfabética na lista).
- `test/fakes.dart` — `FakeAuthService`, `RepositorioDeTeste` (FakeFirebaseFirestore), `receitaExemplo`.

## Convenções
- Gravar no Firestore **sem await** na tela (offline a Future só termina com o servidor; card firestore-escrita-offline).
- Mensagem de erro ao usuário sem `$e`; log só com tipo/código (`debugPrint`), nunca dado da receita ou e-mail.
- Limite novo de campo: mudar junto `receita_repository.dart` (problemaNaReceita) e `firebase/firestore.rules` + testes.
- Inspecionar banco antigo no emulador: `adb exec-out run-as com.example.lista_de_compras cat databases/receitas.db`
  (redirecionar com `cmd /c`, não com o `>` do PowerShell).

## Versionamento
- Repositório em `../` (`Livro de receitas/.git`): `origin` = github.com/Raul-Mozart/livro_de_receita (**privado**), branch `main`.
  Commit/push só com aprovação explícita do usuário (ADR-005).

## Decisões (1 linha cada, mais recente no fim)
- 2026-10-14 · Firebase no lugar do SQLite: Firestore + Auth e-mail/senha no plano Spark; fotos no Storage só com Blaze
  (bucket us-central1). Supabase e AWS descartados (A-008, ADR-015).
- 2026-10-14 · Categorias fixas no código; DAOs e `db_provider.dart` removidos; banco antigo vira cópia de segurança.
