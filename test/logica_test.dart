import 'package:flutter_test/flutter_test.dart';
import 'package:fonoclin/core/formatos.dart';
import 'package:fonoclin/core/validacao.dart';
import 'package:fonoclin/estado/agenda_controller.dart';
import 'package:fonoclin/logica/agenda_logica.dart';
import 'package:fonoclin/logica/indicadores.dart';
import 'package:fonoclin/logica/resumo_financeiro.dart';
import 'package:fonoclin/modelos/agendamento.dart';
import 'package:fonoclin/modelos/cobranca.dart';
import 'package:fonoclin/modelos/solicitacao.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'ajudantes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  // Quarta-feira, 21/10/2026 às 9h.
  final agora = DateTime(2026, 10, 21, 9);
  final dia = DateTime(2026, 10, 21);

  group('AgendaLogica.verificar', () {
    final agenda = [
      ag('a1', dia.comHora(14, 0), profissional: 'ana', sala: 'Sala 02'),
      ag('a2', dia.comHora(15, 30), profissional: 'marcos', sala: 'Sala 01'),
    ];

    test('horário vago para profissional e sala', () {
      final d = AgendaLogica.verificar(
        agenda,
        profissionalId: 'ana',
        sala: 'Sala 02',
        inicio: dia.comHora(10, 0),
        fim: dia.comHora(10, 45),
      );
      expect(d.livre, isTrue);
      expect(d.conflitos, isEmpty);
    });

    test('detecta conflito do profissional', () {
      final d = AgendaLogica.verificar(
        agenda,
        profissionalId: 'ana',
        sala: 'Sala 03',
        inicio: dia.comHora(14, 30),
        fim: dia.comHora(15, 15),
      );
      expect(d.profissionalLivre, isFalse);
      expect(d.salaLivre, isTrue);
    });

    test('detecta sala ocupada por outro profissional', () {
      final d = AgendaLogica.verificar(
        agenda,
        profissionalId: 'ana',
        sala: 'Sala 01',
        inicio: dia.comHora(15, 45),
        fim: dia.comHora(16, 30),
      );
      expect(d.profissionalLivre, isTrue);
      expect(d.salaLivre, isFalse);
    });

    test('ignora o próprio agendamento e os cancelados', () {
      final comCancelado = [
        ...agenda,
        ag(
          'a3',
          dia.comHora(10, 0),
          profissional: 'ana',
          status: StatusAgendamento.cancelado,
        ),
      ];
      expect(
        AgendaLogica.verificar(
          comCancelado,
          profissionalId: 'ana',
          sala: 'Sala 02',
          inicio: dia.comHora(14, 0),
          fim: dia.comHora(14, 45),
          ignorarId: 'a1',
        ).livre,
        isTrue,
      );
      expect(
        AgendaLogica.verificar(
          comCancelado,
          profissionalId: 'ana',
          sala: 'Sala 02',
          inicio: dia.comHora(10, 0),
          fim: dia.comHora(10, 45),
        ).livre,
        isTrue,
      );
    });

    test('horários encostados não conflitam', () {
      final d = AgendaLogica.verificar(
        agenda,
        profissionalId: 'ana',
        sala: 'Sala 02',
        inicio: dia.comHora(14, 45),
        fim: dia.comHora(15, 30),
      );
      expect(d.livre, isTrue);
    });
  });

  test('horariosLivres remove os horários ocupados da grade', () {
    final livres = AgendaLogica.horariosLivres(
      [
        ag('a1', dia.comHora(8, 30)),
        ag('a2', dia.comHora(14, 0)),
        ag('a3', dia.comHora(10, 0), profissional: 'outra'),
      ],
      dia,
      profissionalId: 'ana',
    );
    expect(livres.map(Formatos.hora), ['10:00', '11:30', '15:30', '16:30']);
  });

  test('proxima ignora sessões encerradas e passadas', () {
    final p = AgendaLogica.proxima([
      ag('passada', agora.subtract(const Duration(days: 1))),
      ag(
        'cancelada',
        agora.add(const Duration(hours: 1)),
        status: StatusAgendamento.cancelado,
      ),
      ag('futura2', agora.add(const Duration(days: 3))),
      ag('futura1', agora.add(const Duration(days: 1))),
    ], agora);
    expect(p?.id, 'futura1');
  });

  test('número da semana ISO', () {
    expect(AgendaLogica.numeroDaSemana(DateTime(2024, 10, 24)), 43);
    expect(AgendaLogica.numeroDaSemana(DateTime(2026, 1, 1)), 1);
  });

  group('AgendaController', () {
    final todos = [
      ag('a', dia.comHora(8, 30), status: StatusAgendamento.agendado),
      ag('b', dia.comHora(10, 0), status: StatusAgendamento.confirmado),
      ag(
        'c',
        dia.comHora(11, 30),
        profissional: 'marcos',
        paciente: 'helena',
        status: StatusAgendamento.confirmado,
      ),
      ag('outro-dia', dia.add(const Duration(days: 1)).comHora(8, 30)),
    ];
    final troca = [
      SolicitacaoReagendamento(
        id: 's',
        agendamentoId: 'b',
        pacienteId: 'p1',
        pacienteNome: 'Paciente p1',
        responsavelNome: 'Mãe',
        profissionalId: 'ana',
        profissionalNome: 'Dra. ana',
        sala: 'Sala A',
        horarioAtual: dia.comHora(10, 0),
        horarioPretendido: dia.comHora(15, 0),
        criadoEm: agora,
      ),
    ];

    test('filtra por dia, profissional, status e busca', () {
      final c = AgendaController(hoje: dia);
      expect(c.filtrar(todos, troca).map((a) => a.id), ['a', 'b', 'c']);

      c.filtrarProfissional('marcos');
      expect(c.filtrar(todos, troca).map((a) => a.id), ['c']);

      c.filtrarProfissional(null);
      c.filtrarStatus(FiltroStatus.pendentes);
      // "a" está só agendado e "b" tem pedido de troca.
      expect(c.filtrar(todos, troca).map((a) => a.id), ['a', 'b']);

      c.filtrarStatus(FiltroStatus.confirmados);
      expect(c.filtrar(todos, troca).map((a) => a.id), ['c']);

      c.filtrarStatus(FiltroStatus.todos);
      c.buscar('HELÉNA');
      expect(c.filtrar(todos, troca).map((a) => a.id), ['c']);
    });

    test('contagens ignoram o filtro de status atual', () {
      final c = AgendaController(hoje: dia)
        ..filtrarStatus(FiltroStatus.confirmados);
      final n = c.contagens(todos, troca);
      expect((n.todos, n.pendentes, n.confirmados), (3, 2, 1));
      expect(c.status, FiltroStatus.confirmados);
    });

    test('notifica ouvintes e troca de semana', () {
      final c = AgendaController(hoje: dia);
      var avisos = 0;
      c.addListener(() => avisos++);
      c.mudarSemana(1);
      expect(c.dia, DateTime(2026, 10, 28));
      expect(c.diasDaSemana.first, DateTime(2026, 10, 26));
      expect(avisos, 1);
    });
  });

  group('IndicadoresClinica', () {
    test('calcula ocupação, faturamento e desmarques do dia', () {
      final agenda = [
        ag('1', dia.comHora(8, 30), status: StatusAgendamento.concluido),
        ag('2', dia.comHora(10, 0), status: StatusAgendamento.emAtendimento),
        ag('3', dia.comHora(11, 30)),
        ag('4', dia.comHora(14, 0), status: StatusAgendamento.cancelado),
        // Mesmo dia da semana anterior: 2 sessões.
        ag('5', dia.subtract(const Duration(days: 7)).comHora(8, 30)),
        ag('6', dia.subtract(const Duration(days: 7)).comHora(10, 0)),
      ];
      final cobrancas = [
        cob('c1', 300, dia, pagoEm: dia),
        cob('c2', 200, DateTime(2026, 9, 10), pagoEm: DateTime(2026, 9, 10)),
        cob('c3', 150, dia.add(const Duration(days: 3)), paciente: 'p2'),
      ];
      final ind = IndicadoresClinica.calcular(
        agendamentos: agenda,
        cobrancas: cobrancas,
        numeroProfissionais: 1,
        agora: agora,
      );
      expect(ind.sessoes, 3);
      expect(ind.concluidos, 1);
      expect(ind.emAndamento, 1);
      expect(ind.capacidade, 6);
      expect(ind.vagasLivres, 3);
      expect(ind.ocupacao, 0.5);
      expect(ind.variacaoSessoes, closeTo(0.5, 1e-9));
      expect(ind.faturamentoMes, 300);
      expect(ind.variacaoFaturamento, closeTo(0.5, 1e-9));
      expect(ind.emAberto, 150);
      expect(ind.pacientesEmAberto, 1);
      expect(ind.desmarquesMes, 1);
    });

    test('dias úteis do período semanal', () {
      expect(
        IndicadoresClinica.diasUteis(
          DateTime(2026, 10, 19),
          DateTime(2026, 10, 26),
        ),
        5,
      );
    });
  });

  group('ResumoFinanceiro', () {
    test('recebido, a receber, atraso e mix', () {
      final r = ResumoFinanceiro.calcular(
        [
          cob('pix', 300, dia, pagoEm: dia, forma: FormaPagamento.pix),
          cob('cartao', 100, dia, pagoEm: dia, forma: FormaPagamento.cartao),
          cob('ant', 200, DateTime(2026, 9, 5), pagoEm: DateTime(2026, 9, 5)),
          cob('atrasada', 50, DateTime(2026, 10, 15)),
          cob('pendente', 150, DateTime(2026, 10, 25)),
          cob('novembro', 999, DateTime(2026, 11, 10)),
        ],
        mes: DateTime(2026, 10),
        hoje: agora,
      );
      expect(r.recebido, 400);
      expect(r.recebidoMesAnterior, 200);
      expect(r.variacao, closeTo(1.0, 1e-9));
      expect(r.quantidadeBaixadas, 2);
      expect(r.ticketMedio, 200);
      expect(r.aReceber, 200);
      expect(r.quantidadeAtrasadas, 1);
      expect(r.fracaoAtraso, 0.25);
      expect(r.mix[FormaPagamento.pix], 0.75);
      expect(r.mix[FormaPagamento.cartao], 0.25);
      // Atrasadas primeiro, depois pendentes, depois pagas.
      expect(r.lancamentos.first.id, 'atrasada');
      expect(r.lancamentos.map((c) => c.id), isNot(contains('novembro')));
    });
  });

  group('Formatos', () {
    test('idade e iniciais', () {
      expect(Formatos.idade(DateTime(2020, 10, 22), agora), 5);
      expect(Formatos.idade(DateTime(2020, 10, 21), agora), 6);
      expect(Formatos.idadeTexto(DateTime(1990, 1, 1), agora), 'Adulto');
      expect(Formatos.iniciais('Dra. Ana Costa'), 'AC');
      expect(Formatos.primeiroNome('Dra. Kariny Mylena'), 'Kariny');
    });

    test('datas em português', () {
      expect(Formatos.diaCompleto(dia), 'Quarta-feira, 21 Out');
      expect(Formatos.diaHoraCurto(dia.comHora(15, 0)), 'Qua, 21/10 às 15:00');
      // O intl usa espaço não separável (U+00A0) depois do símbolo.
      expect(Formatos.moeda(38600), 'R\$ 38.600,00');
      expect(
        Formatos.tempoDecorrido(agora, agora.add(const Duration(minutes: 22))),
        'há 22 min',
      );
    });
  });

  group('Validacao', () {
    test('e-mail e senha', () {
      expect(Validacao.email(''), isNotNull);
      expect(Validacao.email('ana@'), 'E-mail inválido');
      expect(Validacao.email('ana@clinica.com.br'), isNull);
      expect(Validacao.senha('123'), 'Mínimo de 6 caracteres');
      expect(Validacao.senha('123456'), isNull);
    });

    test('nome completo e CRFa', () {
      expect(Validacao.nomeCompleto('Ana'), 'Informe nome e sobrenome');
      expect(Validacao.nomeCompleto('Ana Costa'), isNull);
      expect(Validacao.crfa('CRFa 2-19402'), isNull);
      expect(Validacao.crfa('2-19402'), isNull);
      expect(Validacao.crfa('abc'), isNotNull);
    });
  });
}
