import 'package:flutter/material.dart';
import './cadastro.dart';

class AppbarCustomizado extends StatelessWidget implements PreferredSizeWidget {
  final String? titulo;
  final bool mostrarIconeAdicionar;
  
  // Construtor
  const AppbarCustomizado({
    super.key,
    this.titulo,
    this.mostrarIconeAdicionar = true,
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
      actions: mostrarIconeAdicionar
          ? [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Cadastro()),
                  );
                  // Se retornou true, precisamos de um callback no main ou recarregar
                  // Aqui no appbar genérico é difícil forçar reload da tela principal 
                  // sem uma função callback. No entanto, se o main.dart tiver puxado o appbar,
                  // nós podemos passar um callback.
                  // Uma alternativa melhor para reload: 
                  if (result == true) {
                    Navigator.pushReplacementNamed(context, '/'); 
                    // Assumindo que a rota inicial é a do livro de receitas
                  }
                },
              ),
            ]
          : null,
    );
  }

  // Define a altura preferida da AppBar (padrão do Flutter)
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
