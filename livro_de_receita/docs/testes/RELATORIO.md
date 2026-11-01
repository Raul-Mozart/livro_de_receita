# Relatório de testes — Livro de receitas

## 2026-11-01 · Testador · auditoria D-009 do agente reserva (sem commit sobre c04dca8)

- Escopo: remoção de `lib/data/migracao_sqlite.dart` (`migrarBancoAntigo`, `repararFotosDoAppAntigo`) e de
  `test/migracao_sqlite_test.dart`; `main.dart` `_conectarUsuarioFirebase` só conecta o `ReceitaRepository`.
- Comandos: `flutter test --reporter failures-only` (suíte inteira), `flutter analyze`.
- Resumo: 27 passaram, 0 falharam, 0 ignorados. Cobertura não medida. Analyze: 8 infos antigos em `cadastro_page.dart`.
- Dependências do código removido: nenhuma referência restante em `lib/` ou `test/` (`migrarBancoAntigo`,
  `repararFotosDoAppAntigo`, `idMigrado`, `receitasDoBancoAntigo`, `package:sqflite`). `path` e `path_provider` seguem em uso
  (`cadastro_page.dart`). A ligação login → repositório continua coberta por `test/auth_test.dart` (injeção de `conectarUsuario`).
- Teste novo: `test/recipe_image_fallback_d009_test.dart` (2): receita que ainda aponta para a foto do app anterior
  (`/data/user/0/com.example.lista_de_compras/...`, que deixou de ser reparada) mostra o ícone de reserva sem exceção;
  caminho nulo ou vazio idem.

### Bugs
- **BUG-L01 · BAIXO** · `pubspec.yaml:12` mantém `sqflite: ^2.0.0+4` sem nenhum uso. Esperado: removido (`flutter pub remove
  sqflite`), menos código nativo no APK e uma licença a menos para o juridico. O reserva não pôde mexer no pubspec.
- **BUG-L02 · BAIXO** · documentação desatualizada cita a migração removida: `CLAUDE.md`, `README.md`, `docs/DATABASE.md`,
  `docs/DIAGRAMAS.md`, `docs/FIREBASE.md` (busca por `migracao_sqlite|migrarBancoAntigo|repararFotos|receitas.db`).

### Riscos
- **RISCO-L03 · MÉDIO** · a D-009 tinha a condição "quando não houver mais aparelho com `receitas.db` a migrar"; não há
  evidência registrada de que a condição foi atendida. Aparelho que ainda tenha o banco antigo (ou fotos em
  `<documentos>/fotos_app_antigo` não reparadas) perde a cópia automática: os dados ficam no aparelho, invisíveis no app,
  e as fotos antigas passam a mostrar o ícone de reserva. Confirmar com o dono antes do commit. Os arquivos antigos
  (`receitas.db`, `fotos_app_antigo/`, marcas `.json`) ficam órfãos no aparelho: avaliar limpeza (juridico/LGPD, BAIXO).
- Sem teste de ponta a ponta do primeiro login com Firebase real (só com fakes).
