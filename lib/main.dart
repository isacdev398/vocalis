import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'dados/banco_dados.dart';
import 'dados/clinica_repositorio.dart';
import 'estado/sessao.dart';
import 'firebase_options.dart';
import 'servicos/auth_servico.dart';

/// Para forçar a demonstração mesmo com Firebase configurado:
///   flutter run -d chrome --dart-define=DEMO=true
const _forcarDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  final sessao = Sessao(firebase: await _conectarFirebase());
  await sessao.iniciar();

  runApp(FonoGestaoApp(sessao: sessao));
}

/// Tenta ligar o Firebase. Se não estiver configurado, devolve null e o app
/// segue no modo demonstração (dados em memória).
Future<Backend?> _conectarFirebase() async {
  if (_forcarDemo) return null;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Cache local do Firestore: as leituras ficam gravadas no aparelho, o app
    // abre e funciona sem internet, e as gravações feitas offline são enviadas
    // quando a conexão volta. O limite evita que o cache cresça sem fim.
    // (No Android/iOS já vem ligado; na Web precisa ser pedido.)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 50 * 1024 * 1024,
    );
    return Backend(
      auth: FirebaseAuthServico(),
      repo: ClinicaRepositorio(FirestoreBanco(FirebaseFirestore.instance)),
      local: false,
    );
  } catch (e) {
    debugPrint('Firebase indisponível, usando modo demonstração: $e');
    return null;
  }
}
