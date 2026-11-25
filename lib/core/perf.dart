import 'package:flutter/foundation.dart';

// Flags pra comparar antes/depois (ver PERFORMANCE.md):
//   flutter run --profile --dart-define=ESTRESSE=5000 --dart-define=OTIMIZADO=false
//   flutter run --profile --dart-define=ESTRESSE=5000
abstract final class Perf {
  // false = versão antiga (Column com tudo, cálculo no build, coleção inteira).
  // Não é const porque os testes trocam o valor.
  static bool otimizado = const bool.fromEnvironment(
    'OTIMIZADO',
    defaultValue: true,
  );

  // registros extras gerados na demo (0 = desligado)
  static const int estresse = int.fromEnvironment('ESTRESSE');
}

// Na web não tem Isolate, então o compute roda na mesma thread.
Future<R> calcularForaDaUI<E, R>(
  ComputeCallback<E, R> funcao,
  E entrada, {
  String? rotulo,
}) => compute(funcao, entrada, debugLabel: rotulo);
