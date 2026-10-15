import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

// Falha de login/cadastro com mensagem pronta para o usuário
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

// Traduz o código de erro do Firebase Auth para uma mensagem em português
String mensagemErroAuth(String code) {
  switch (code) {
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'user-disabled':
      return 'Esta conta foi desativada.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'INVALID_LOGIN_CREDENTIALS':
      return 'E-mail ou senha incorretos.';
    case 'email-already-in-use':
      return 'Já existe uma conta com este e-mail. Use "Entrar".';
    case 'weak-password':
      return 'Senha fraca: use pelo menos 6 caracteres.';
    case 'too-many-requests':
      return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
    case 'network-request-failed':
      return 'Sem conexão. Entrar na conta pela primeira vez precisa de internet.';
    case 'operation-not-allowed':
      return 'Login por e-mail não está ativado no projeto do Firebase.';
    default:
      return 'Não foi possível concluir. Tente de novo.';
  }
}

// Login do app (o Firebase fica atrás desta interface para os testes de tela)
abstract class AuthService {
  // UID do usuário conectado; null quando ninguém está conectado
  Stream<String?> uidChanges();

  String? get currentEmail;

  Future<void> signIn(String email, String password);

  Future<void> register(String email, String password);

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, {this.timeout = const Duration(seconds: 20)});

  final FirebaseAuth _auth;
  final Duration timeout;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Future<void> signIn(String email, String password) => _run(
    () => _auth.signInWithEmailAndPassword(email: email.trim(), password: password),
  );

  @override
  Future<void> register(String email, String password) => _run(
    () => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password),
  );

  @override
  Future<void> sendPasswordReset(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action().timeout(timeout);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(mensagemErroAuth(e.code));
    } on TimeoutException {
      throw const AuthFailure('O servidor não respondeu. Confira a internet e tente de novo.');
    }
  }
}
