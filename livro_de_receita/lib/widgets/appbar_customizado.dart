import 'package:flutter/material.dart';
import 'package:livro_de_receita/pages/cadastro_page.dart';

class AppbarCustomizado extends StatelessWidget implements PreferredSizeWidget {
  final String? titulo;
  final bool mostrarIconeAdicionar;
  // Recarrega a tela de origem depois que uma receita nova é salva
  final VoidCallback? aoCriarReceita;
  // Menu da conta (só na tela inicial): e-mail conectado e opção de sair
  final String? emailUsuario;
  final VoidCallback? aoSair;

  // Construtor
  const AppbarCustomizado({
    super.key,
    this.titulo,
    this.mostrarIconeAdicionar = true,
    this.aoCriarReceita,
    this.emailUsuario,
    this.aoSair,
  });

  @override
  Widget build(BuildContext context) {
    // Verifica se é possível voltar à tela anterior
    final bool canPop = Navigator.canPop(context);

    return AppBar(
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          : null, // Não mostra botão se não houver tela anterior

      // Define se usa título personalizado ou padrão
      title: Text(
        titulo ?? "Livro de Receitas",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      // Define ações do lado direito da barra
      actions: [
        if (mostrarIconeAdicionar)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova receita',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Cadastro()),
              );
              if (result == true) {
                if (aoCriarReceita != null) {
                  aoCriarReceita!();
                } else if (context.mounted) {
                  // Sem callback, recarrega a rota inicial do livro de receitas
                  Navigator.pushReplacementNamed(context, '/');
                }
              }
            },
          ),
        if (aoSair != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Conta',
            onSelected: (opcao) {
              if (opcao == 'sair') aoSair!();
            },
            itemBuilder: (context) => [
              if (emailUsuario != null)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    emailUsuario!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              const PopupMenuItem<String>(
                value: 'sair',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sair'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // Define a altura preferida da AppBar (padrão do Flutter)
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
