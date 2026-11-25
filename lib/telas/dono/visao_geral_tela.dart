import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/formatos.dart';
import '../../core/perf.dart';
import '../../core/tema.dart';
import '../../dados/clinica_repositorio.dart';
import '../../estado/sessao.dart';
import '../../logica/indicadores.dart';
import '../../modelos/agendamento.dart';
import '../../modelos/cobranca.dart';
import '../../modelos/solicitacao.dart';
import '../../modelos/usuario.dart';
import '../../rotas.dart';
import '../../widgets/comuns.dart';

class _Dados {
  _Dados(this.agendamentos, this.cobrancas, this.equipe, this.solicitacoes);
  final List<Agendamento> agendamentos;
  final List<Cobranca> cobrancas;
  final List<Usuario> equipe;
  final List<SolicitacaoReagendamento> solicitacoes;
}

typedef _EntradaIndicadores = ({
  List<Agendamento> agendamentos,
  List<Cobranca> cobrancas,
  int numeroProfissionais,
  DateTime agora,
  Periodo periodo,
});

/// Roda dentro do Isolate (por isso é uma função de topo).
IndicadoresClinica _calcularIndicadores(_EntradaIndicadores e) =>
    IndicadoresClinica.calcular(
      agendamentos: e.agendamentos,
      cobrancas: e.cobrancas,
      numeroProfissionais: e.numeroProfissionais,
      agora: e.agora,
      periodo: e.periodo,
    );

/// Dono — "Visão Geral da Clínica" (Stitch).
class VisaoGeralTela extends StatefulWidget {
  const VisaoGeralTela({super.key});

  @override
  State<VisaoGeralTela> createState() => _VisaoGeralTelaState();
}

class _VisaoGeralTelaState extends State<VisaoGeralTela> {
  Periodo _periodo = Periodo.hoje;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ClinicaRepositorio>();
    final usuario = context.watch<Sessao>().usuario!;

    // Otimizado: o painel só usa o mês atual e o anterior (mais a semana que
    // pode virar o mês), então baixa só esse intervalo.
    final hoje = DateTime.now();
    final de = DateTime(hoje.year, hoje.month - 1, 1);
    final ate = DateTime(hoje.year, hoje.month + 1, 8);

    return Observar<_Dados>(
      chave: repo,
      stream: () => Rx.combineLatest4(
        Perf.otimizado ? repo.agendamentosEntre(de, ate) : repo.agendamentos(),
        repo.cobrancas(),
        repo.equipe(),
        repo.solicitacoes(),
        _Dados.new,
      ),
      builder: (context, d) {
        final t = DateTime.now();
        // Arredondado ao minuto para a memoização do Calculado funcionar.
        final agora = DateTime(t.year, t.month, t.day, t.hour, t.minute);
        final profissionais = d.equipe
            .where((u) => u.ehProfissionalClinico && !u.convidado)
            .toList();
        return Calculado<_EntradaIndicadores, IndicadoresClinica>(
          entrada: (
            agendamentos: d.agendamentos,
            cobrancas: d.cobrancas,
            numeroProfissionais: profissionais.length,
            agora: agora,
            periodo: _periodo,
          ),
          calcular: _calcularIndicadores,
          rotulo: 'indicadores',
          builder: (context, ind) => _pagina(context, d, ind, agora, usuario),
        );
      },
    );
  }

  Widget _pagina(
    BuildContext context,
    _Dados d,
    IndicadoresClinica ind,
    DateTime agora,
    Usuario usuario,
  ) {
    final titulo = switch (_periodo) {
      Periodo.hoje => 'Sessões de hoje',
      Periodo.semana => 'Sessões da semana',
      Periodo.mes => 'Sessões do mês',
    };
    final nomeCurto = usuario.nome.split(' ').take(2).join(' ');

    return Conteudo(
      children: [
        Row(children: [Pilula(Formatos.mesAno(agora))]),
        const SizedBox(height: 12),
        Text(
          'Olá, $nomeCurto',
          style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
        ),
        Text(
          usuario.especialidade.isEmpty
              ? 'Diretora clínica'
              : usuario.especialidade,
          style: TemaApp.corpo(size: 15, color: Cores.textoSuave),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in Periodo.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: p == Periodo.hoje
                        ? const Icon(Icons.today, size: 18)
                        : null,
                    label: Text(p.rotulo),
                    selected: _periodo == p,
                    selectedColor: Cores.primaria,
                    labelStyle: TemaApp.corpo(
                      weight: FontWeight.w600,
                      color: _periodo == p ? Colors.white : Cores.texto,
                    ),
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _periodo = p),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Atalho(
                rotulo: 'Agenda',
                valor: 'Do dia',
                icone: Icons.calendar_month,
                destaque: true,
                onTap: () => context.go(Rotas.agenda),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Atalho(
                rotulo: 'Financeiro',
                valor: 'Do mês',
                icone: Icons.payments_outlined,
                onTap: () => context.go(Rotas.financeiro),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Indicadores', style: TemaApp.titulo(size: 20)),
            ),
            Relogio(
              intervalo: 30,
              builder: (_, _) => Text(
                'Atualizado às ${Formatos.hora(DateTime.now())}',
                style: TemaApp.corpo(size: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sessões
        Cartao(
          faixa: Cores.primaria,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconeQuadrado(Icons.groups_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: TemaApp.titulo(size: 18)),
                        Text(
                          'Horários ocupados',
                          style: TemaApp.corpo(size: 12),
                        ),
                      ],
                    ),
                  ),
                  Pilula.menta(
                    '${(ind.ocupacao * 100).round()}% Ocupação',
                    icone: Icons.trending_up,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text(
                    '${ind.sessoes}',
                    style: TemaApp.titulo(size: 36, height: 1),
                  ),
                  Text(
                    'atendimentos programados',
                    style: TemaApp.corpo(size: 15),
                  ),
                  if (ind.variacaoSessoes != null)
                    Text(
                      '${ind.variacaoSessoes! >= 0 ? '+' : ''}'
                      '${(ind.variacaoSessoes! * 100).round()}% vs período ant.',
                      style: TemaApp.corpo(
                        size: 13,
                        weight: FontWeight.w700,
                        color: ind.variacaoSessoes! >= 0
                            ? Cores.primaria
                            : Cores.erroForte,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _BarraSegmentada(
                partes: [
                  (ind.concluidos.toDouble(), Cores.primaria),
                  (
                    (ind.emAndamento + ind.aguardando).toDouble(),
                    Cores.secundaria,
                  ),
                  (ind.vagasLivres.toDouble(), Cores.containerAlto),
                ],
              ),
              const SizedBox(height: 12),
              Bloco(
                child: Row(
                  children: [
                    _Numero('Concluídos', ind.concluidos),
                    _Numero('Esperando', ind.emAndamento + ind.aguardando),
                    _Numero('Vagas livres', ind.vagasLivres),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.go(Rotas.agenda),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ver agenda completa'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Financeiro resumido
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Cartao(
                onTap: () => context.go(Rotas.financeiro),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconeQuadrado(
                          Icons.account_balance_wallet_outlined,
                          tamanho: 34,
                        ),
                        const Spacer(),
                        if (ind.variacaoFaturamento != null)
                          ind.variacaoFaturamento! >= 0
                              ? Pilula.menta(
                                  '+${(ind.variacaoFaturamento! * 100).round()}%',
                                )
                              : Pilula.erro(
                                  '${(ind.variacaoFaturamento! * 100).round()}%',
                                ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Faturamento do mês', style: TemaApp.corpo(size: 13)),
                    FittedBox(
                      child: Text(
                        Formatos.moedaPartes(ind.faturamentoMes).$1,
                        style: TemaApp.titulo(size: 24),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ant.: ${Formatos.moedaPartes(ind.faturamentoMesAnterior).$1}',
                      style: TemaApp.corpo(size: 12, color: Cores.primaria),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Cartao(
                onTap: () => context.go(Rotas.financeiro),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconeQuadrado(
                          Icons.pending_actions,
                          tamanho: 34,
                          fundo: Cores.secundariaContainer,
                          cor: Cores.ardosia,
                        ),
                        const Spacer(),
                        Pilula('${ind.pacientesEmAberto} pac.'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('A receber', style: TemaApp.corpo(size: 13)),
                    FittedBox(
                      child: Text(
                        Formatos.moedaPartes(ind.emAberto).$1,
                        style: TemaApp.titulo(size: 24),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Ver financeiro', style: TemaApp.corpo(size: 12)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CartaoDesmarques(ind: ind, solicitacoes: d.solicitacoes),
        const SizedBox(height: 24),

        // Salas
        TituloSecao(
          'Ocupação das salas',
          icone: Icons.meeting_room_outlined,
          acao: Text(_periodo.rotulo, style: TemaApp.corpo(size: 12)),
        ),
        Cartao(
          child: Column(
            children: [
              for (final e in ind.ocupacaoSalas.entries) ...[
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e.value >= 0.5
                            ? Cores.primaria
                            : Cores.secundaria,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.key, style: TemaApp.corpo(size: 15)),
                    ),
                    Text(
                      '${(e.value * 100).round()}%',
                      style: TemaApp.corpo(
                        weight: FontWeight.w700,
                        color: Cores.primaria,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                BarraProgresso(
                  e.value,
                  cor: e.value >= 0.5 ? Cores.primaria : Cores.secundaria,
                ),
                const SizedBox(height: 14),
              ],
              if (ind.vagasLivres > 0 && _periodo == Periodo.hoje)
                Bloco(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dá para encaixar',
                              style: TemaApp.corpo(weight: FontWeight.w700),
                            ),
                            Text(
                              'Há ${ind.vagasLivres} horários livres hoje na '
                              'grade dos profissionais.',
                              style: TemaApp.corpo(size: 13),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => context.go(Rotas.agenda),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('Avisar a recepção'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Equipe
        TituloSecao(
          'Equipe',
          icone: Icons.badge_outlined,
          acao: TextButton(
            onPressed: () => context.go(Rotas.equipe),
            child: const Text('Ver equipe'),
          ),
        ),
        Cartao(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final u in d.equipe.where(
                (u) => u.id != usuario.id && !u.convidado,
              ))
                _LinhaEquipe(
                  usuario: u,
                  agendamentos: d.agendamentos,
                  quantidade: ind.atendimentosPorProfissional[u.id] ?? 0,
                  agora: agora,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Cores.container,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Cores.menta,
                child: Icon(Icons.shield_outlined, color: Cores.primaria),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ind.ocupacao >= 0.7
                          ? 'Agenda bem ocupada'
                          : 'Ainda há horários livres',
                      style: TemaApp.corpo(size: 15, weight: FontWeight.w700),
                    ),
                    Text(
                      '${(ind.ocupacao * 100).round()}% dos horários ocupados '
                      'no período.',
                      style: TemaApp.corpo(size: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho({
    required this.rotulo,
    required this.valor,
    required this.icone,
    required this.onTap,
    this.destaque = false,
  });
  final String rotulo;
  final String valor;
  final IconData icone;
  final VoidCallback onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final corTexto = destaque ? Colors.white : Cores.texto;
    return Material(
      color: destaque ? Cores.primaria : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: destaque ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Cores.borda),
          ),
          child: Row(
            children: [
              IconeQuadrado(
                icone,
                fundo: destaque
                    ? const Color(0x33FFFFFF)
                    : Cores.secundariaContainer,
                cor: destaque ? Colors.white : Cores.ardosia,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo.toUpperCase(),
                      style: TemaApp.corpo(
                        size: 11,
                        weight: FontWeight.w700,
                        color: destaque ? Colors.white70 : Cores.textoSuave,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      valor,
                      overflow: TextOverflow.ellipsis,
                      style: TemaApp.titulo(size: 18, color: corTexto),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarraSegmentada extends StatelessWidget {
  const _BarraSegmentada({required this.partes});
  final List<(double, Color)> partes;

  @override
  Widget build(BuildContext context) {
    final total = partes.fold(0.0, (s, p) => s + p.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
        child: total == 0
            ? Container(color: Cores.containerAlto)
            : Row(
                children: [
                  for (final (v, c) in partes)
                    if (v > 0)
                      Expanded(
                        flex: (v * 1000 / total).round().clamp(1, 1000),
                        child: Container(color: c),
                      ),
                ],
              ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor);
  final String rotulo;
  final int valor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(rotulo, style: TemaApp.corpo(size: 12)),
        Text('$valor', style: TemaApp.titulo(size: 18, color: Cores.primaria)),
      ],
    ),
  );
}

class _CartaoDesmarques extends StatelessWidget {
  const _CartaoDesmarques({required this.ind, required this.solicitacoes});
  final IndicadoresClinica ind;
  final List<SolicitacaoReagendamento> solicitacoes;

  @override
  Widget build(BuildContext context) {
    final taxa = ind.taxaDesmarque;
    final (rotulo, fundo, cor) = taxa < 0.05
        ? ('Excelente', Cores.container, Cores.texto)
        : taxa < 0.1
        ? ('Atenção', Cores.alertaFundo, Cores.alertaTexto)
        : ('Crítico', Cores.erroFundo, Cores.erroTexto);
    final pendentes = solicitacoes.where((s) => s.pendente).toList();
    final resolvida = solicitacoes
        .where((s) => s.status == StatusSolicitacao.aprovada)
        .firstOrNull;

    return Cartao(
      faixa: Cores.secundaria,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconeQuadrado(
                Icons.event_busy_outlined,
                fundo: Cores.container,
                cor: Cores.texto,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faltas e desmarques',
                      style: TemaApp.titulo(size: 18),
                    ),
                    Text(
                      'Total no mês: ${ind.desmarquesMes} de ${ind.sessoesMes} sessões',
                      style: TemaApp.corpo(size: 12),
                    ),
                  ],
                ),
              ),
              Pilula(
                '${(taxa * 100).toStringAsFixed(1)}% ($rotulo)',
                fundo: fundo,
                cor: cor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendentes.isNotEmpty)
            Bloco(
              cor: Cores.alertaFundo,
              child: Row(
                children: [
                  const Icon(Icons.update, color: Cores.alertaTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${pendentes.length} ${pendentes.length == 1 ? 'reagendamento aguarda' : 'reagendamentos aguardam'} '
                      'a recepção (${pendentes.first.pacienteNome}).',
                      style: TemaApp.corpo(color: Cores.alertaTexto),
                    ),
                  ),
                ],
              ),
            )
          else if (resolvida != null)
            Bloco(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: Cores.primaria),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          children: [
                            Text(
                              'Reagendamento resolvido',
                              style: TemaApp.corpo(weight: FontWeight.w700),
                            ),
                            Pilula(resolvida.resolvidoPor),
                          ],
                        ),
                        Text(
                          '${resolvida.pacienteNome} remarcado(a) para '
                          '${Formatos.diaHoraCurto(resolvida.horarioFinal ?? resolvida.horarioPretendido)} '
                          '(${resolvida.profissionalNome}).',
                          style: TemaApp.corpo(size: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaEquipe extends StatelessWidget {
  const _LinhaEquipe({
    required this.usuario,
    required this.agendamentos,
    required this.quantidade,
    required this.agora,
  });
  final Usuario usuario;
  final List<Agendamento> agendamentos;
  final int quantidade;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    Widget direita;
    if (u.perfil == Perfil.recepcao) {
      direita = const Pilula.menta('Ativa', ponto: true);
    } else {
      final hoje = agendamentos
          .where(
            (a) =>
                a.profissionalId == u.id &&
                a.inicio.mesmoDia(agora) &&
                a.status.ativo,
          )
          .toList();
      final emSessao = hoje.any(
        (a) => a.status == StatusAgendamento.emAtendimento,
      );
      final proximo = hoje
          .where((a) => a.inicio.isAfter(agora) && !a.status.encerrado)
          .firstOrNull;
      direita = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$quantidade atend.',
            style: TemaApp.corpo(
              size: 15,
              weight: FontWeight.w700,
              color: Cores.primaria,
            ),
          ),
          Text(
            emSessao
                ? 'Em sessão'
                : proximo != null
                ? 'Próximo às ${Formatos.hora(proximo.inicio)}'
                : 'Agenda livre',
            style: TemaApp.corpo(size: 12),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Avatar(u.nome, tamanho: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.nome,
                  style: TemaApp.corpo(size: 15, weight: FontWeight.w600),
                ),
                Text(
                  u.especialidade.isEmpty ? u.cargo : u.especialidade,
                  style: TemaApp.corpo(size: 12, color: Cores.textoSuave),
                ),
              ],
            ),
          ),
          direita,
        ],
      ),
    );
  }
}
