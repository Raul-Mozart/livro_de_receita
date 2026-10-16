// Configuração do Firebase do projeto real "livro-de-receitas-97927", gerada por `flutterfire configure`
// (veja docs/FIREBASE.md). A chave de API identifica o projeto e não é segredo: quem protege os dados
// são as regras em firebase/firestore.rules. Emuladores locais: --dart-define=USE_FIREBASE_EMULATOR=true.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase não configurado para esta plataforma. Rode `flutterfire configure`.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB-fCV6FpvgoO2YMwzg7qgTquQWpqBSDn8',
    appId: '1:534341435631:web:ea206d28d5f6d02b231b1a',
    messagingSenderId: '534341435631',
    projectId: 'livro-de-receitas-97927',
    authDomain: 'livro-de-receitas-97927.firebaseapp.com',
    storageBucket: 'livro-de-receitas-97927.firebasestorage.app',
    measurementId: 'G-WS96ME6BFP',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCoEyqNcbU0j6Dg5Ckr7gR9UlcTuFh8gwM',
    appId: '1:534341435631:android:aa083a83dc81cd8d231b1a',
    messagingSenderId: '534341435631',
    projectId: 'livro-de-receitas-97927',
    storageBucket: 'livro-de-receitas-97927.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCYDTcJNGtbzyaAp6k0PmVSycsqdKAEMjY',
    appId: '1:534341435631:ios:29335c59df9554de231b1a',
    messagingSenderId: '534341435631',
    projectId: 'livro-de-receitas-97927',
    storageBucket: 'livro-de-receitas-97927.firebasestorage.app',
    iosBundleId: 'com.raulmozart.livroDeReceitas',
  );
}
