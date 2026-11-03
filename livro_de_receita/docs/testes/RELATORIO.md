# Relatório de testes — Livro de receitas

## 2026-11-02 · Testador · T-163 infos de `cadastro_page.dart` e CI sem `--no-fatal-infos` (sem commit sobre 03b4867)

- Escopo: `lib/pages/cadastro_page.dart` (catch com comentário; `if (!mounted) return` antes do SnackBar da foto
  recuperada; `DropdownButtonFormField` `value` → `initialValue` + `key: ValueKey(_categoriaId)`); `../.github/workflows/ci.yml`
  (`flutter analyze` sem `--no-fatal-infos`).
- Comandos: `flutter analyze` (como no CI, sem a flag) e `flutter test --reporter failures-only` (suíte inteira).
- Resumo: **32 testes; 31 passaram, 0 falharam, 1 ignorado (BUG-L03)**. Analyze: **No issues found** (os 8 infos
  zeraram; o CI sem a flag passa). Cobertura não medida.
- Teste novo: `test/categoria_dropdown_t163_test.dart` (5). Risco do briefing conferido: categoria carregada por
  código aparece selecionada.
  | Caso | Resultado |
  |---|---|
  | Receita nova: 1ª categoria do catálogo (Bebidas) selecionada | OK |
  | Edição: receita com Salgados → campo mostra Salgados (valor 1) | OK |
  | Edição: trocar para Doces depois de carregada → valor 2 e o form valida | OK |
  | Rascunho com `categoriaId: 2` (arquivo real via `path_provider` simulado) → Doces e o nome do rascunho | OK |
  | Receita com categoria fora do catálogo (99) | ignorado: BUG-L03 |
  Obs. de teste: o carregamento da edição só termina depois do `path_provider` (unidades salvas); sem simular o
  canal e sem `runAsync` o teste vê a categoria padrão. Não é defeito do app.

### Bugs
- **BUG-L03 · BAIXO** (anterior ao T-163, o `value` antigo tinha o mesmo assert) · `cadastro_page.dart:911`. Passos:
  abrir a edição de uma receita cujo `categoriaId` não está em `Categoria.todas` (ex.: 99, dado antigo ou editado no
  Firestore). Esperado: tela abre e pede para escolher a categoria. Obtido: em debug, assert do `DropdownButton`
  ("There should be exactly one item with [DropdownButton]'s value"); em release o campo fica sem item e o salvar
  regrava o id desconhecido. Causa: `_categoriaId` vem da receita sem conferir o catálogo. Sugestão: em
  `_carregarReceitaParaEdicao` e `_recuperarRascunho`, usar o id só se `Categoria.porId(id) != null` (senão `null`,
  e o validador pede a categoria). Teste pronto: tirar o `skip` em `test/categoria_dropdown_t163_test.dart`.
- BUG-L01 e BUG-L02 (BAIXO) seguem abertos.

### Riscos
- A `key` muda a cada escolha da categoria: o campo é recriado (perde o foco). Sem efeito visível no teste; conferir
  com TalkBack que o foco não pula para o topo depois de escolher (designer-ux).

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
