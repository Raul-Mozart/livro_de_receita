# 🗄️ Como Funciona o Banco de Dados - Livro de Receitas

As receitas ficam no **Cloud Firestore** (Firebase), separadas por usuário. O app grava primeiro no
**banco local do Firestore** (no próprio aparelho) e o Firebase envia para a nuvem quando há internet.
Configuração do projeto Firebase: [FIREBASE.md](FIREBASE.md).

## 📋 Resumo
- [Onde os dados ficam](#-onde-os-dados-ficam)
- [Como uma receita é guardada](#-como-uma-receita-é-guardada)
- [Salvar, buscar, editar e excluir](#-salvar-buscar-editar-e-excluir)
- [Sem internet](#-sem-internet)
- [Quem pode ver o quê (regras)](#-quem-pode-ver-o-quê-regras)
- [Banco antigo (SQLite)](#-banco-antigo-sqlite)

---

## 📱 Onde os dados ficam

| Lugar | O que guarda |
|---|---|
| Firebase Auth | a conta (e-mail e senha) |
| Firestore na nuvem | `users/{uid}/receitas/{id}`: as receitas de cada usuário |
| Banco local do Firestore (no aparelho) | cópia das receitas + gravações ainda não enviadas (sem limite de tamanho) |
| Arquivos do app | fotos tiradas no aparelho, rascunho do cadastro, unidades recentes |

As categorias (Salgados = 1, Doces = 2, Bebidas = 3) são fixas no código: `Categoria.todas`.

---

## 🗂️ Como uma receita é guardada

Uma receita é **um documento** com os ingredientes e os passos dentro dele (não há mais 4 tabelas):

```json
users/{uid}/receitas/{id}
{
  "titulo": "Bolo de Chocolate",
  "descricao": "Receita de bolo de chocolate",
  "tempoPreparo": 0, "porcoes": 0, "dificuldade": 0,
  "dataCadastro": "<Timestamp>",
  "categoriaId": 2,
  "imagem": "assets/images/bolo.png",
  "ingredientes": [
    { "nome": "farinha", "quantidade": 2.0, "unidadeMedida": "xícaras" },
    { "nome": "ovos", "quantidade": 3.0, "unidadeMedida": "un" }
  ],
  "passos": [
    { "ordem": 1, "descricao": "Misture os ingredientes", "feito": false },
    { "ordem": 2, "descricao": "Asse por 40 minutos", "feito": false }
  ],
  "atualizadoEm": "<horário do servidor>"
}
```

- O `id` é gerado pelo Firestore no aparelho (texto), então funciona sem internet e não colide entre aparelhos.
- Salvar é **uma gravação só**: não existe receita salva pela metade.
- Excluir apaga o documento inteiro: não sobram ingredientes "órfãos".

---

## 💾 Salvar, buscar, editar e excluir

Tudo passa por `lib/data/receita_repository.dart` (`ReceitaRepository.atual`, definido no login):

```dart
// Nova receita (id == null) ou edição (id preenchido): grava a receita inteira
final id = ReceitaRepository.atual.save(receita);

// Lista ordenada por título (a tela filtra por categoria)
final receitas = await ReceitaRepository.atual.getAll();

// Uma receita com ingredientes e passos (1 leitura)
final receita = await ReceitaRepository.atual.getById(id);

// Exclui a receita (e a foto tirada no aparelho, se houver)
await ReceitaRepository.atual.delete(id, imagem: receita.imagem);
```

`save` valida os mesmos limites das regras do Firestore (`problemaNaReceita`): título de 1 a 200
caracteres, categoria 1/2/3, até 200 ingredientes e 200 passos.

---

## 📴 Sem internet

- **Gravar:** o dado vai para o banco local na hora e entra numa fila; o Firestore envia sozinho quando a
  conexão volta. Por isso o app **não espera** a resposta do servidor ao salvar (offline essa espera não termina).
- **Ler:** sem resposta do servidor em 10 s, a leitura usa o que já está no aparelho.
- **Entrar na conta:** o primeiro login precisa de internet; depois a sessão fica salva e o app abre offline.
- **Sair da conta:** o app espera o envio do que está pendente; sem internet, avisa antes de sair.
- Aparelho novo: as receitas ficam disponíveis offline depois de abrir o app uma vez com internet.

---

## 🔒 Quem pode ver o quê (regras)

`firebase/firestore.rules`: cada usuário só lê e grava `users/{seu uid}/receitas/**`; campos, tipos e
tamanhos são conferidos no servidor. Testes das regras: `cd firebase && npm test` (emulador).

---

## 🗃️ Banco antigo (SQLite)

Versões anteriores guardavam tudo em `receitas.db` (tabelas `categoria`, `receita`, `ingrediente`,
`passo_preparo`). Até 2026-11-01 o app copiava esse banco para a conta no primeiro login (IDs
`local-<id antigo>-<data em ms>`, que continuam nas receitas migradas). A cópia automática foi removida (D-009):
o único aparelho já tinha migrado. Uma cópia do banco antigo fica em `Livro de receitas/backups/` (leitura manual).
