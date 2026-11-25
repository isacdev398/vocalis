import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../casca.dart';

class CarregandoTela extends StatelessWidget {
  const CarregandoTela({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LogoFono(tamanho: 64),
          const SizedBox(height: 20),
          Text('Vocalis', style: TemaApp.titulo(size: 22)),
          const SizedBox(height: 20),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    ),
  );
}
