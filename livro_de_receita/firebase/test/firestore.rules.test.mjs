// Testes das regras do Firestore no emulador (npm test, dentro de firebase/).
import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-livro-receitas',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function validRecipe(overrides = {}) {
  return {
    titulo: 'Bolo de cenoura',
    descricao: 'Receita de bolo de cenoura',
    tempoPreparo: 0,
    porcoes: 0,
    dificuldade: 0,
    dataCadastro: Timestamp.fromDate(new Date('2026-10-14T12:00:00Z')),
    categoriaId: 2,
    imagem: null,
    ingredientes: [{ nome: 'cenoura', quantidade: 3, unidadeMedida: 'un' }],
    passos: [{ ordem: 1, descricao: 'Bater tudo', feito: false }],
    atualizadoEm: serverTimestamp(),
    ...overrides,
  };
}

function dbAs(uid) {
  return env.authenticatedContext(uid).firestore();
}

function recipeOf(db, uid, id = 'r1') {
  return doc(db, `users/${uid}/receitas/${id}`);
}

async function seedRecipe(uid, id = 'r1') {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(recipeOf(ctx.firestore(), uid, id), validRecipe({ atualizadoEm: Timestamp.now() }));
  });
}

test('dono cria, lê e exclui a própria receita', async () => {
  const db = dbAs('alice');
  await assertSucceeds(setDoc(recipeOf(db, 'alice'), validRecipe()));
  await assertSucceeds(getDoc(recipeOf(db, 'alice')));
  await assertSucceeds(deleteDoc(recipeOf(db, 'alice')));
});

test('dono atualiza a receita inteira', async () => {
  await seedRecipe('alice');
  const db = dbAs('alice');
  await assertSucceeds(setDoc(recipeOf(db, 'alice'), validRecipe({ titulo: 'Bolo de laranja' })));
});

test('outro usuário não lê, não grava e não exclui', async () => {
  await seedRecipe('alice');
  const db = dbAs('bob');
  await assertFails(getDoc(recipeOf(db, 'alice')));
  await assertFails(setDoc(recipeOf(db, 'alice', 'r2'), validRecipe()));
  await assertFails(deleteDoc(recipeOf(db, 'alice')));
});

test('sem login não lê nem grava', async () => {
  await seedRecipe('alice');
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(recipeOf(db, 'alice')));
  await assertFails(setDoc(recipeOf(db, 'alice', 'r2'), validRecipe()));
});

test('aceita receita sem o campo imagem e com imagem de texto', async () => {
  const db = dbAs('alice');
  const semImagem = validRecipe();
  delete semImagem.imagem;
  await assertSucceeds(setDoc(recipeOf(db, 'alice', 'a'), semImagem));
  await assertSucceeds(
    setDoc(recipeOf(db, 'alice', 'b'), validRecipe({ imagem: 'assets/images/bolo.png' })),
  );
});

test('recusa campo desconhecido', async () => {
  const db = dbAs('alice');
  await assertFails(setDoc(recipeOf(db, 'alice'), validRecipe({ dono: 'bob' })));
});

test('recusa campo obrigatório ausente', async () => {
  const db = dbAs('alice');
  const semPassos = validRecipe();
  delete semPassos.passos;
  await assertFails(setDoc(recipeOf(db, 'alice'), semPassos));
});

test('recusa título vazio ou longo demais', async () => {
  const db = dbAs('alice');
  await assertFails(setDoc(recipeOf(db, 'alice', 'a'), validRecipe({ titulo: '' })));
  await assertFails(setDoc(recipeOf(db, 'alice', 'b'), validRecipe({ titulo: 'x'.repeat(201) })));
});

test('recusa categoria fora do catálogo e tipos errados', async () => {
  const db = dbAs('alice');
  await assertFails(setDoc(recipeOf(db, 'alice', 'a'), validRecipe({ categoriaId: 4 })));
  await assertFails(setDoc(recipeOf(db, 'alice', 'b'), validRecipe({ porcoes: '4' })));
  await assertFails(
    setDoc(recipeOf(db, 'alice', 'c'), validRecipe({ dataCadastro: '2026-10-14' })),
  );
});

test('recusa listas grandes demais', async () => {
  const db = dbAs('alice');
  const muitos = Array.from({ length: 201 }, (_, i) => ({ ordem: i + 1, descricao: 'p', feito: false }));
  await assertFails(setDoc(recipeOf(db, 'alice'), validRecipe({ passos: muitos })));
});

test('recusa atualizadoEm vindo do relógio do aparelho', async () => {
  const db = dbAs('alice');
  await assertFails(
    setDoc(recipeOf(db, 'alice'), validRecipe({ atualizadoEm: Timestamp.fromDate(new Date()) })),
  );
});

test('nega caminhos fora de users/{uid}/receitas', async () => {
  const db = dbAs('alice');
  await assertFails(setDoc(doc(db, 'receitas/r1'), validRecipe()));
  await assertFails(setDoc(doc(db, 'users/alice'), { nome: 'Alice' }));
});
