import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:livro_de_receita/firebase_options.dart';

// Emuladores locais do Firebase: --dart-define=USE_FIREBASE_EMULATOR=true
// (celular físico: --dart-define=FIREBASE_EMULATOR_HOST=<IP do computador>).
// O projeto provisório "demo-..." só existe no emulador, então liga o emulador sozinho.
const bool _useEmulatorFlag = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const String _emulatorHostFlag = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
const int firestoreEmulatorPort = 8080;
const int authEmulatorPort = 9099;

bool usesFirebaseEmulator(FirebaseOptions options) =>
    _useEmulatorFlag || options.projectId.startsWith('demo-');

String firebaseEmulatorHost() {
  if (_emulatorHostFlag.isNotEmpty) return _emulatorHostFlag;
  // O emulador Android enxerga o computador pelo endereço 10.0.2.2
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return 'localhost';
}

Future<void> initFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);

  // Banco local do Firestore: guarda tudo no aparelho (sem descarte por tamanho)
  // e envia as gravações para a nuvem quando houver conexão
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (usesFirebaseEmulator(options)) {
    final host = firebaseEmulatorHost();
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestoreEmulatorPort);
    await FirebaseAuth.instance.useAuthEmulator(host, authEmulatorPort);
  }
}
