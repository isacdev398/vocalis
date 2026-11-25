import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/tema.dart';
import 'dados/clinica_repositorio.dart';
import 'estado/sessao.dart';
import 'rotas.dart';

class FonoGestaoApp extends StatefulWidget {
  const FonoGestaoApp({super.key, required this.sessao});

  final Sessao sessao;

  @override
  State<FonoGestaoApp> createState() => _FonoGestaoAppState();
}

class _FonoGestaoAppState extends State<FonoGestaoApp> {
  late final GoRouter _roteador = criarRoteador(widget.sessao);

  @override
  void dispose() {
    _roteador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Sessao>.value(value: widget.sessao),
        // muda ao entrar/sair da demo
        ProxyProvider<Sessao, ClinicaRepositorio>(
          update: (_, sessao, _) => sessao.repo,
        ),
      ],
      child: MaterialApp.router(
        title: 'Vocalis',
        debugShowCheckedModeBanner: false,
        theme: TemaApp.claro(),
        routerConfig: _roteador,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }
}
