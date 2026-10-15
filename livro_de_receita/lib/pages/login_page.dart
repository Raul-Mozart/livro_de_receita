import 'package:flutter/material.dart';
import 'package:livro_de_receita/data/auth_service.dart';

final RegExp _emailValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

// Tela de entrada: login, criação de conta e recuperação de senha por e-mail
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();
  bool _criarConta = false;
  bool _enviando = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  String? _validarEmail(String? valor) {
    final email = valor?.trim() ?? '';
    if (email.isEmpty) return 'Informe o e-mail';
    if (!_emailValido.hasMatch(email)) return 'E-mail inválido';
    return null;
  }

  String? _validarSenha(String? valor) {
    if (valor == null || valor.isEmpty) return 'Informe a senha';
    if (_criarConta && valor.length < 6) return 'Use pelo menos 6 caracteres';
    return null;
  }

  Future<void> _enviar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      if (_criarConta) {
        await widget.auth.register(_emailController.text, _senhaController.text);
      } else {
        await widget.auth.signIn(_emailController.text, _senhaController.text);
      }
      // Com sucesso, o portão de login troca esta tela pela tela inicial
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _esqueciSenha() async {
    final problema = _validarEmail(_emailController.text);
    if (problema != null) {
      setState(() => _erro = 'Digite seu e-mail acima para receber o link de nova senha.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await widget.auth.sendPasswordReset(_emailController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Se existir uma conta com este e-mail, enviamos um link para criar uma nova senha.',
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _alternarModo() {
    setState(() {
      _criarConta = !_criarConta;
      _erro = null;
      _confirmacaoController.clear();
    });
  }

  InputDecoration _decoracao(String rotulo, IconData icone, {Widget? sufixo}) {
    return InputDecoration(
      labelText: rotulo,
      prefixIcon: Icon(icone),
      suffixIcon: sufixo,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estiloLink = TextButton.styleFrom(foregroundColor: Colors.red.shade700);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo.png', height: 96),
                    const SizedBox(height: 16),
                    const Text(
                      'Livro de Receitas',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _criarConta
                          ? 'Crie sua conta para guardar suas receitas na nuvem.'
                          : 'Entre para ver suas receitas em qualquer aparelho.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: _decoracao('E-mail', Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: _validarEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senhaController,
                      decoration: _decoracao(
                        'Senha',
                        Icons.lock_outline,
                        sufixo: IconButton(
                          tooltip: _senhaVisivel ? 'Esconder senha' : 'Mostrar senha',
                          icon: Icon(
                            _senhaVisivel ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                        ),
                      ),
                      obscureText: !_senhaVisivel,
                      autofillHints: [
                        _criarConta ? AutofillHints.newPassword : AutofillHints.password,
                      ],
                      textInputAction:
                          _criarConta ? TextInputAction.next : TextInputAction.done,
                      onFieldSubmitted: (_) => _criarConta ? null : _enviar(),
                      validator: _validarSenha,
                    ),
                    if (_criarConta) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmacaoController,
                        decoration: _decoracao('Confirme a senha', Icons.lock_outline),
                        obscureText: !_senhaVisivel,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _enviar(),
                        validator:
                            (v) =>
                                v != _senhaController.text
                                    ? 'As senhas não são iguais'
                                    : null,
                      ),
                    ],
                    if (_erro != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _erro!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _enviando ? null : _enviar,
                        child:
                            _enviando
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  _criarConta ? 'Criar conta' : 'Entrar',
                                  style: const TextStyle(fontSize: 16),
                                ),
                      ),
                    ),
                    if (!_criarConta)
                      TextButton(
                        style: estiloLink,
                        onPressed: _enviando ? null : _esqueciSenha,
                        child: const Text('Esqueci minha senha'),
                      ),
                    TextButton(
                      style: estiloLink,
                      onPressed: _enviando ? null : _alternarModo,
                      child: Text(
                        _criarConta
                            ? 'Já tenho conta: entrar'
                            : 'Não tem conta? Criar conta',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
