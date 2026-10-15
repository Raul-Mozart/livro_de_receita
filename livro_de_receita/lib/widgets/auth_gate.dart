import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livro_de_receita/data/auth_service.dart';
import 'package:livro_de_receita/pages/login_page.dart';

// Mostra a tela de login sem usuário conectado e a tela inicial com usuário conectado.
// A sessão fica salva no aparelho: depois do 1º login o app abre direto, mesmo sem internet.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.onSignedIn,
    required this.onSignedOut,
    required this.home,
  });

  final AuthService auth;
  // Prepara os dados do usuário (repositório, migração) antes de mostrar a tela inicial
  final Future<void> Function(String uid) onSignedIn;
  final VoidCallback onSignedOut;
  final Widget home;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<String?>? _subscription;
  bool _aguardandoSessao = true;
  String? _uid;
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.uidChanges().listen(_aoMudarUsuario);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _aoMudarUsuario(String? uid) async {
    if (uid == null) {
      widget.onSignedOut();
      if (mounted) {
        setState(() {
          _aguardandoSessao = false;
          _uid = null;
          _pronto = false;
        });
      }
      return;
    }
    if (uid == _uid) return;
    setState(() {
      _aguardandoSessao = false;
      _uid = uid;
      _pronto = false;
    });
    await widget.onSignedIn(uid);
    if (mounted && _uid == uid) setState(() => _pronto = true);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (_aguardandoSessao || (uid != null && !_pronto)) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
          ),
        ),
      );
    }
    if (uid == null) return LoginPage(auth: widget.auth);
    // Chave por usuário: trocar de conta recria a tela inicial com os dados do novo usuário
    return KeyedSubtree(key: ValueKey(uid), child: widget.home);
  }
}
