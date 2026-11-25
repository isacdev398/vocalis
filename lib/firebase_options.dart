// Provisório: o `flutterfire configure` sobrescreve este arquivo.
// Enquanto isso o currentPlatform lança erro e o app cai no modo demo.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase ainda não configurado. Rode "flutterfire configure".',
  );
}
