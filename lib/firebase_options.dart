// ARQUIVO PROVISÓRIO.
//
// Ele é substituído automaticamente quando você roda:
//   flutterfire configure
// (veja o passo a passo no README.md).
//
// Enquanto o Firebase não estiver configurado, `currentPlatform` lança um erro
// e o app inicia sozinho no MODO DEMONSTRAÇÃO, com dados em memória.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase ainda não configurado. Rode "flutterfire configure".',
  );
}
