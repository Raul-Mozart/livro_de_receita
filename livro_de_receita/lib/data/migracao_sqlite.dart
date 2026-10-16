import 'dart:convert';
import 'dart:io';

import 'package:livro_de_receita/data/receita_repository.dart';
import 'package:livro_de_receita/models/categoria.dart';
import 'package:livro_de_receita/models/ingrediente.dart';
import 'package:livro_de_receita/models/passo_preparo.dart';
import 'package:livro_de_receita/models/receita.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Banco SQLite das versões anteriores do app e a marca de que ele já foi copiado
const String arquivoBancoAntigo = 'receitas.db';
const String arquivoMarcaMigracao = 'migracao_firestore.json';
const String tituloPadrao = 'Receita sem título';

// ID determinístico: copiar de novo a mesma receita sobrescreve o documento (não duplica)
String idMigrado(int idAntigo, DateTime dataCadastro) =>
    'local-$idAntigo-${dataCadastro.millisecondsSinceEpoch}';

String _limitar(String texto, int max) => texto.length <= max ? texto : texto.substring(0, max);

int? _inteiro(Object? valor) => valor is num ? valor.toInt() : null;

// Monta as receitas a partir das linhas das tabelas antigas (receita, ingrediente, passo_preparo),
// já dentro dos limites das regras do Firestore
List<Receita> receitasDoBancoAntigo({
  required List<Map<String, Object?>> receitas,
  required List<Map<String, Object?>> ingredientes,
  required List<Map<String, Object?>> passos,
}) {
  final ingredientesPorReceita = <int, List<Map<String, Object?>>>{};
  for (final linha in ingredientes) {
    final receitaId = _inteiro(linha['receita_id']);
    if (receitaId != null) ingredientesPorReceita.putIfAbsent(receitaId, () => []).add(linha);
  }
  final passosPorReceita = <int, List<Map<String, Object?>>>{};
  for (final linha in passos) {
    final receitaId = _inteiro(linha['receita_id']);
    if (receitaId != null) passosPorReceita.putIfAbsent(receitaId, () => []).add(linha);
  }

  final resultado = <Receita>[];
  for (final linha in receitas) {
    final idAntigo = _inteiro(linha['id']);
    if (idAntigo == null) continue;

    final dataCadastro =
        DateTime.tryParse((linha['data_cadastro'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final titulo = ((linha['titulo'] as String?) ?? '').trim();
    final categoriaId = _inteiro(linha['categoria_id']);
    final imagem = linha['imagem'] as String?;

    // Mesma ordem das telas antigas: ingredientes por nome, passos por ordem
    final ingredientesDaReceita =
        (ingredientesPorReceita[idAntigo] ?? [])
            .map(
              (m) => Ingrediente(
                nome: (m['nome'] as String?) ?? '',
                quantidade: (m['quantidade'] as num?)?.toDouble() ?? 0,
                unidadeMedida: (m['unidade_medida'] as String?) ?? '',
              ),
            )
            .toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
    final passosDaReceita =
        (passosPorReceita[idAntigo] ?? [])
            .map(
              (m) => PassoPreparo(
                ordem: _inteiro(m['ordem']) ?? 0,
                descricao: (m['descricao'] as String?) ?? '',
                feito: m['feito'] == 1 || m['feito'] == true,
              ),
            )
            .toList()
          ..sort((a, b) => a.ordem.compareTo(b.ordem));

    resultado.add(
      Receita(
        id: idMigrado(idAntigo, dataCadastro),
        titulo: titulo.isEmpty ? tituloPadrao : _limitar(titulo, tituloMaxLength),
        descricao: _limitar((linha['descricao'] as String?) ?? '', descricaoMaxLength),
        tempoPreparo: _inteiro(linha['tempo_preparo']) ?? 0,
        porcoes: _inteiro(linha['porcoes']) ?? 0,
        dificuldade: _inteiro(linha['dificuldade']) ?? 0,
        dataCadastro: dataCadastro,
        categoriaId:
            categoriaId != null && Categoria.porId(categoriaId) != null ? categoriaId : 1,
        imagem: imagem != null && imagem.length <= imagemMaxLength ? imagem : null,
        ingredientes: ingredientesDaReceita.take(itensMaxPorLista).toList(),
        passos: passosDaReceita.take(itensMaxPorLista).toList(),
      ),
    );
  }
  return resultado;
}

// Copia uma única vez o banco antigo do aparelho para a conta conectada.
// Devolve quantas receitas foram copiadas (0 se não havia banco antigo ou se já tinha copiado).
// O arquivo antigo fica no aparelho como cópia de segurança.
Future<int> migrarBancoAntigo(ReceitaRepository repo) async {
  final documentos = await getApplicationDocumentsDirectory();
  final marca = File(p.join(documentos.path, arquivoMarcaMigracao));
  if (await marca.exists()) return 0;

  final caminho = p.join(await getDatabasesPath(), arquivoBancoAntigo);
  if (!await databaseExists(caminho)) return 0;

  final db = await openDatabase(caminho, readOnly: true, singleInstance: false);
  final List<Receita> receitas;
  try {
    receitas = receitasDoBancoAntigo(
      receitas: await db.query('receita'),
      ingredientes: await db.query('ingrediente'),
      passos: await db.query('passo_preparo'),
    );
  } finally {
    await db.close();
  }

  for (final receita in receitas) {
    repo.save(receita);
  }
  await marca.writeAsString(
    jsonEncode({'receitas': receitas.length, 'data': DateTime.now().toIso8601String()}),
  );
  return receitas.length;
}

// Fotos do app anterior (com.example.lista_de_compras) ficavam na pasta privada dele, que este app não lê.
// Copiadas por adb para <documentos>/fotos_app_antigo (docs/FIREBASE.md), as receitas passam a usar a cópia.
const String pacoteAntigo = 'com.example.lista_de_compras';
const String pastaFotosAppAntigo = 'fotos_app_antigo';
const String arquivoMarcaFotos = 'fotos_app_antigo.json';

// Aponta as receitas com foto do app anterior para a cópia em <documentos>/fotos_app_antigo e devolve
// quantas corrigiu. Só marca como feito quando nenhuma receita aponta mais para o app anterior
// (foto ainda não copiada: tenta de novo na próxima abertura).
Future<int> repararFotosDoAppAntigo(ReceitaRepository repo, {String? pastaDocumentos}) async {
  pastaDocumentos ??= (await getApplicationDocumentsDirectory()).path;
  final marca = File(p.join(pastaDocumentos, arquivoMarcaFotos));
  if (await marca.exists()) return 0;
  final pastaFotos = p.join(pastaDocumentos, pastaFotosAppAntigo);
  if (!await Directory(pastaFotos).exists()) return 0;

  var corrigidas = 0;
  var pendentes = 0;
  for (final receita in await repo.getAll()) {
    final imagem = receita.imagem;
    if (imagem == null || !imagem.contains('/$pacoteAntigo/')) continue;
    final copia = p.join(pastaFotos, p.basename(imagem));
    if (await File(copia).exists()) {
      receita.imagem = copia;
      repo.save(receita);
      corrigidas++;
    } else {
      pendentes++;
    }
  }
  if (pendentes == 0) {
    await marca.writeAsString(
      jsonEncode({'fotos': corrigidas, 'data': DateTime.now().toIso8601String()}),
    );
  }
  return corrigidas;
}
