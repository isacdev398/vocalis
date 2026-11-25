import '../modelos/cobranca.dart';

class ResumoFinanceiro {
  const ResumoFinanceiro({
    required this.recebido,
    required this.recebidoMesAnterior,
    required this.quantidadeBaixadas,
    required this.aReceber,
    required this.quantidadeAbertas,
    required this.valorAtrasado,
    required this.quantidadeAtrasadas,
    required this.mix,
    required this.lancamentos,
  });

  final double recebido;
  final double recebidoMesAnterior;
  final int quantidadeBaixadas;
  final double aReceber;
  final int quantidadeAbertas;
  final double valorAtrasado;
  final int quantidadeAtrasadas;

  // fração por forma de pagamento, soma 1
  final Map<FormaPagamento, double> mix;

  // do mês (venceu ou pagou no mês) + as em aberto de antes
  final List<Cobranca> lancamentos;

  double get ticketMedio =>
      quantidadeBaixadas == 0 ? 0 : recebido / quantidadeBaixadas;
  double? get variacao =>
      recebidoMesAnterior == 0 ? null : recebido / recebidoMesAnterior - 1;
  double get fracaoAtraso => aReceber == 0 ? 0 : valorAtrasado / aReceber;

  factory ResumoFinanceiro.calcular(
    List<Cobranca> todas, {
    required DateTime mes,
    required DateTime hoje,
  }) {
    bool noMes(DateTime d, DateTime ref) =>
        d.year == ref.year && d.month == ref.month;
    final anterior = DateTime(mes.year, mes.month - 1, 1);
    final fimDoMes = DateTime(mes.year, mes.month + 1, 1);

    final pagasNoMes = todas
        .where((c) => c.paga && noMes(c.pagoEm!, mes))
        .toList();
    final recebido = pagasNoMes.fold(0.0, (s, c) => s + c.valor);

    final abertas = todas
        .where((c) => !c.paga && c.vencimento.isBefore(fimDoMes))
        .toList();
    final atrasadas = abertas
        .where((c) => c.situacao(hoje) == SituacaoCobranca.atrasada)
        .toList();

    final mix = <FormaPagamento, double>{};
    for (final forma in FormaPagamento.values) {
      final v = pagasNoMes
          .where((c) => c.forma == forma)
          .fold(0.0, (s, c) => s + c.valor);
      mix[forma] = recebido == 0 ? 0 : v / recebido;
    }

    // atrasadas, pendentes, depois pagas mais recentes.
    // Calcula o peso antes; dentro do comparador era chamado n·log n vezes
    // e foi o que deixou isso lento (ver PERFORMANCE.md).
    final peso = <Cobranca, int>{
      for (final c in {...pagasNoMes, ...abertas})
        c: switch (c.situacao(hoje)) {
          SituacaoCobranca.atrasada => 0,
          SituacaoCobranca.pendente => 1,
          SituacaoCobranca.paga => 2,
        },
    };
    final lancamentos = peso.keys.toList()
      ..sort((a, b) {
        final p = peso[a]!.compareTo(peso[b]!);
        if (p != 0) return p;
        return (b.pagoEm ?? b.vencimento).compareTo(a.pagoEm ?? a.vencimento);
      });

    return ResumoFinanceiro(
      recebido: recebido,
      recebidoMesAnterior: todas
          .where((c) => c.paga && noMes(c.pagoEm!, anterior))
          .fold(0.0, (s, c) => s + c.valor),
      quantidadeBaixadas: pagasNoMes.length,
      aReceber: abertas.fold(0.0, (s, c) => s + c.valor),
      quantidadeAbertas: abertas.length,
      valorAtrasado: atrasadas.fold(0.0, (s, c) => s + c.valor),
      quantidadeAtrasadas: atrasadas.length,
      mix: mix,
      lancamentos: lancamentos,
    );
  }
}
