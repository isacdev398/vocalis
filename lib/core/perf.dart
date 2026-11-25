import 'package:flutter/foundation.dart';

/// Chaves de desempenho usadas para medir o "antes vs. depois".
///
/// Rode o app em modo profile e compare as duas versões no Flutter DevTools:
///
///   flutter run --profile --dart-define=ESTRESSE=5000 --dart-define=OTIMIZADO=false
///   flutter run --profile --dart-define=ESTRESSE=5000
///
/// Veja PERFORMANCE.md para o roteiro completo.
abstract final class Perf {
  /// true (padrão) = versão otimizada. false = versão "antes", que reproduz a
  /// abordagem ingênua: lista montada inteira, cálculos dentro do build() na
  /// thread de UI e consultas que baixam a coleção inteira.
  ///
  /// Não é `const` só para os testes poderem comparar as duas versões.
  static bool otimizado = const bool.fromEnvironment(
    'OTIMIZADO',
    defaultValue: true,
  );

  /// Quantos registros extras a demonstração gera para estressar o app
  /// (cobranças no mês atual e agendamentos antigos). 0 = desligado.
  static const int estresse = int.fromEnvironment('ESTRESSE');
}

/// Executa [funcao] fora da thread de UI.
///
/// No Android/iOS/desktop o `compute` cria um Isolate (outra thread, com
/// memória própria), então o cálculo pesado não trava a animação. Na Web não
/// existem Isolates: o `compute` roda na mesma thread, sem ganho.
Future<R> calcularForaDaUI<E, R>(
  ComputeCallback<E, R> funcao,
  E entrada, {
  String? rotulo,
}) => compute(funcao, entrada, debugLabel: rotulo);
