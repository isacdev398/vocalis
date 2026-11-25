import '../core/formatos.dart';
import '../modelos/agendamento.dart';
import '../modelos/cobranca.dart';

enum Periodo {
  hoje('Hoje'),
  semana('Esta semana'),
  mes('Este mês');

  const Periodo(this.rotulo);
  final String rotulo;

  /// Intervalo [inicio, fim) do período que contém [agora].
  (DateTime, DateTime) intervalo(DateTime agora) {
    final dia = agora.inicioDoDia;
    return switch (this) {
      Periodo.hoje => (dia, dia.add(const Duration(days: 1))),
      Periodo.semana => (
        dia.subtract(Duration(days: dia.weekday - 1)),
        dia.add(Duration(days: 8 - dia.weekday)),
      ),
      Periodo.mes => (
        DateTime(dia.year, dia.month, 1),
        DateTime(dia.year, dia.month + 1, 1),
      ),
    };
  }

  /// Mesmo intervalo, deslocado para o período anterior.
  (DateTime, DateTime) anterior(DateTime agora) {
    final (i, f) = intervalo(agora);
    return switch (this) {
      Periodo.hoje => (
        i.subtract(const Duration(days: 7)),
        f.subtract(const Duration(days: 7)),
      ),
      Periodo.semana => (
        i.subtract(const Duration(days: 7)),
        f.subtract(const Duration(days: 7)),
      ),
      Periodo.mes => (DateTime(i.year, i.month - 1, 1), i),
    };
  }
}

/// Números do painel "Visão Geral" do dono, calculados a partir dos dados reais.
class IndicadoresClinica {
  const IndicadoresClinica({
    required this.sessoes,
    required this.concluidos,
    required this.emAndamento,
    required this.capacidade,
    required this.variacaoSessoes,
    required this.faturamentoMes,
    required this.faturamentoMesAnterior,
    required this.emAberto,
    required this.pacientesEmAberto,
    required this.desmarquesMes,
    required this.sessoesMes,
    required this.ocupacaoSalas,
    required this.atendimentosPorProfissional,
  });

  /// Sessões ativas (não canceladas/faltas) no período.
  final int sessoes;
  final int concluidos;

  /// Pacientes na recepção ou em atendimento agora.
  final int emAndamento;

  /// Horários disponíveis no período (profissionais × grade × dias úteis).
  final int capacidade;

  /// Variação em relação ao período anterior (0.04 = +4%).
  final double? variacaoSessoes;
  final double faturamentoMes;
  final double faturamentoMesAnterior;
  final double emAberto;
  final int pacientesEmAberto;
  final int desmarquesMes;
  final int sessoesMes;

  /// Sala → ocupação de 0 a 1 no período.
  final Map<String, double> ocupacaoSalas;

  /// profissionalId → atendimentos no período.
  final Map<String, int> atendimentosPorProfissional;

  int get sessoesHoje => sessoes;
  int get vagasLivres => (capacidade - sessoes).clamp(0, capacidade);
  int get aguardando => (sessoes - concluidos - emAndamento).clamp(0, sessoes);
  double get ocupacao =>
      capacidade == 0 ? 0 : (sessoes / capacidade).clamp(0, 1);
  double get taxaDesmarque => sessoesMes == 0 ? 0 : desmarquesMes / sessoesMes;
  double? get variacaoFaturamento => faturamentoMesAnterior == 0
      ? null
      : faturamentoMes / faturamentoMesAnterior - 1;

  static int diasUteis(DateTime inicio, DateTime fim) {
    var n = 0;
    for (
      var d = inicio;
      d.isBefore(fim);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (d.weekday <= DateTime.friday) n++;
    }
    return n;
  }

  factory IndicadoresClinica.calcular({
    required List<Agendamento> agendamentos,
    required List<Cobranca> cobrancas,
    required int numeroProfissionais,
    required DateTime agora,
    Periodo periodo = Periodo.hoje,
  }) {
    bool mesmoMes(DateTime d, DateTime ref) =>
        d.year == ref.year && d.month == ref.month;
    bool dentro(DateTime d, (DateTime, DateTime) r) =>
        !d.isBefore(r.$1) && d.isBefore(r.$2);

    final intervalo = periodo.intervalo(agora);
    final noPeriodo = agendamentos
        .where((a) => dentro(a.inicio, intervalo) && a.status.ativo)
        .toList();
    final anteriores = agendamentos
        .where(
          (a) => dentro(a.inicio, periodo.anterior(agora)) && a.status.ativo,
        )
        .length;

    // Hoje conta como dia de trabalho mesmo se for fim de semana.
    final dias = periodo == Periodo.hoje
        ? 1
        : diasUteis(intervalo.$1, intervalo.$2);

    final mesAnterior = DateTime(agora.year, agora.month - 1, 1);
    double somaPagas(DateTime ref) => cobrancas
        .where((c) => c.paga && mesmoMes(c.pagoEm!, ref))
        .fold(0.0, (s, c) => s + c.valor);

    final abertas = cobrancas.where((c) => !c.paga).toList();
    final doMes = agendamentos.where((a) => mesmoMes(a.inicio, agora)).toList();

    final porProfissional = <String, int>{};
    for (final a in noPeriodo) {
      porProfissional.update(a.profissionalId, (v) => v + 1, ifAbsent: () => 1);
    }

    return IndicadoresClinica(
      sessoes: noPeriodo.length,
      concluidos: noPeriodo
          .where((a) => a.status == StatusAgendamento.concluido)
          .length,
      emAndamento: noPeriodo
          .where(
            (a) =>
                a.status == StatusAgendamento.naRecepcao ||
                a.status == StatusAgendamento.emAtendimento,
          )
          .length,
      capacidade: numeroProfissionais * Salas.grade.length * dias,
      variacaoSessoes: anteriores == 0
          ? null
          : noPeriodo.length / anteriores - 1,
      faturamentoMes: somaPagas(agora),
      faturamentoMesAnterior: somaPagas(mesAnterior),
      emAberto: abertas.fold(0.0, (s, c) => s + c.valor),
      pacientesEmAberto: abertas.map((c) => c.pacienteId).toSet().length,
      desmarquesMes: doMes.where((a) => !a.status.ativo).length,
      sessoesMes: doMes.length,
      ocupacaoSalas: {
        for (final sala in Salas.todas)
          sala:
              (noPeriodo.where((a) => a.sala == sala).length /
                      (Salas.grade.length * dias))
                  .clamp(0.0, 1.0),
      },
      atendimentosPorProfissional: porProfissional,
    );
  }
}
