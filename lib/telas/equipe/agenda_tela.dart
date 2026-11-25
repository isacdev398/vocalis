import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/formatos.dart';
import '../../core/perf.dart';
import '../../core/tema.dart';
import '../../dados/clinica_repositorio.dart';
import '../../estado/agenda_controller.dart';
import '../../estado/sessao.dart';
import '../../logica/agenda_logica.dart';
import '../../modelos/agendamento.dart';
import '../../modelos/solicitacao.dart';
import '../../modelos/usuario.dart';
import '../../rotas.dart';
import '../../widgets/comuns.dart';
import 'novo_agendamento_folha.dart';

class _DadosAgenda {
  _DadosAgenda(this.agendamentos, this.solicitacoes, this.profissionais);
  final List<Agendamento> agendamentos;
  final List<SolicitacaoReagendamento> solicitacoes;
  final List<Usuario> profissionais;

  List<SolicitacaoReagendamento> get pendentes =>
      solicitacoes.where((s) => s.pendente).toList();
}

/// Recepção — "Agenda Diária" (Stitch). Também usada pela fono e pelo dono.
class AgendaTela extends StatelessWidget {
  const AgendaTela({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<Sessao>().usuario!;
    return ChangeNotifierProvider(
      // A fono abre a agenda já filtrada nos próprios atendimentos.
      create: (_) => AgendaController(
        profissionalId: usuario.perfil == Perfil.fono ? usuario.id : null,
      ),
      child: const _AgendaConteudo(),
    );
  }
}

class _AgendaConteudo extends StatelessWidget {
  const _AgendaConteudo();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ClinicaRepositorio>();
    final usuario = context.watch<Sessao>().usuario!;
    final ctrl = context.watch<AgendaController>();

    // Otimizado: baixa só a semana visível (consulta por intervalo de datas).
    // Ao trocar de semana a chave muda e o Observar refaz a consulta.
    final semana = ctrl.inicioSemana;
    final fimSemana = DateTime(semana.year, semana.month, semana.day + 7);

    return Observar<_DadosAgenda>(
      chave: Perf.otimizado ? (repo, semana) : repo,
      stream: () => Rx.combineLatest3(
        Perf.otimizado
            ? repo.agendamentosEntre(semana, fimSemana)
            : repo.agendamentos(),
        repo.solicitacoes(),
        repo.profissionais(),
        _DadosAgenda.new,
      ),
      builder: (context, d) {
        final agora = DateTime.now();
        final pendentes = ctrl.filtrarSolicitacoes(d.pendentes);
        final doDia = ctrl.filtrar(d.agendamentos, d.pendentes);
        final cont = ctrl.contagens(d.agendamentos, d.pendentes);
        final trocaPorAgendamento = {
          for (final s in d.pendentes) s.agendamentoId: s,
        };
        final profissionalFiltrado = d.profissionais
            .where((p) => p.id == ctrl.profissionalId)
            .firstOrNull;
        final livres = profissionalFiltrado == null
            ? <DateTime>[]
            : AgendaLogica.horariosLivres(
                d.agendamentos,
                ctrl.dia,
                profissionalId: profissionalFiltrado.id,
              ).where((h) => h.isAfter(agora)).toList();

        // Linha do tempo: atendimentos + horários livres, em ordem.
        final itens = <(DateTime, Widget)>[
          for (final a in doDia)
            (
              a.inicio,
              _ItemAgenda(
                agendamento: a,
                troca: trocaPorAgendamento[a.id],
                usuario: usuario,
                agora: agora,
              ),
            ),
          for (final h in livres)
            (
              h,
              _HorarioLivre(
                inicio: h,
                profissional: profissionalFiltrado!,
                onAgendar: () => abrirNovoAgendamento(
                  context,
                  profissionais: d.profissionais,
                  dia: h,
                  profissionalId: profissionalFiltrado.id,
                ),
              ),
            ),
        ]..sort((a, b) => a.$1.compareTo(b.$1));

        return Conteudo(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pilula.lilas(switch (usuario.perfil) {
                  Perfil.fono => usuario.nome,
                  Perfil.dono => usuario.nome,
                  _ => 'Recepção · ${usuario.nome}',
                }, ponto: true),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.perfil == Perfil.fono
                            ? 'Minha Agenda'
                            : 'Agenda',
                        style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Cores.textoSuave,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${Formatos.diaSemana(ctrl.dia)}, '
                            '${ctrl.dia.day} de ${Formatos.mesCurto(ctrl.dia)}',
                            style: TemaApp.corpo(
                              size: 15,
                              color: Cores.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => abrirNovoAgendamento(
                    context,
                    profissionais: d.profissionais,
                    dia: ctrl.dia,
                    profissionalId: ctrl.profissionalId,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SeletorSemana(agendamentos: d.agendamentos),
            const SizedBox(height: 16),
            TextField(
              onChanged: ctrl.buscar,
              decoration: const InputDecoration(
                hintText:
                    'Buscar paciente por nome, responsável ou profissional',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.tune),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipFiltro(
                    rotulo: 'Todos',
                    icone: Icons.groups,
                    ativo: ctrl.profissionalId == null,
                    onTap: () => ctrl.filtrarProfissional(null),
                  ),
                  for (final p in d.profissionais)
                    _ChipFiltro(
                      rotulo: p.nome,
                      detalhe: p.especialidade.contains('Audio')
                          ? '(Audio)'
                          : '(Fono)',
                      ponto: true,
                      ativo: ctrl.profissionalId == p.id,
                      onTap: () => ctrl.filtrarProfissional(p.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipStatus(
                    rotulo: 'Todos',
                    n: cont.todos,
                    ativo: ctrl.status == FiltroStatus.todos,
                    onTap: () => ctrl.filtrarStatus(FiltroStatus.todos),
                  ),
                  _ChipStatus(
                    rotulo: 'Pendentes / Troca',
                    n: cont.pendentes,
                    ativo: ctrl.status == FiltroStatus.pendentes,
                    cor: Cores.secundariaContainer,
                    onTap: () => ctrl.filtrarStatus(FiltroStatus.pendentes),
                  ),
                  _ChipStatus(
                    rotulo: 'Confirmados',
                    n: cont.confirmados,
                    ativo: ctrl.status == FiltroStatus.confirmados,
                    cor: Colors.white,
                    onTap: () => ctrl.filtrarStatus(FiltroStatus.confirmados),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final s in pendentes) ...[
              _CartaoSolicitacao(
                solicitacao: s,
                agora: agora,
                podeAvaliar: usuario.perfil != Perfil.fono,
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Text('Horários do dia', style: TemaApp.titulo(size: 20)),
                const SizedBox(width: 8),
                Pilula(
                  '${Formatos.diaSemanaCurto(ctrl.dia)}, ${Formatos.diaMes(ctrl.dia)}',
                ),
                const Spacer(),
                const Icon(Icons.schedule, size: 16, color: Cores.primaria),
                const SizedBox(width: 4),
                Text(
                  '${doDia.length} agend.',
                  style: TemaApp.corpo(
                    size: 13,
                    color: Cores.primaria,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (itens.isEmpty)
              const EstadoVazio(
                icone: Icons.event_busy,
                titulo: 'Nenhum horário neste dia',
                texto: 'Use os filtros acima ou toque em "Novo" para agendar.',
              ),
            for (final (i, item) in itens.indexed)
              _LinhaDoTempo(
                inicio: item.$1,
                fim: item.$2 is _ItemAgenda
                    ? (item.$2 as _ItemAgenda).agendamento.fim
                    : item.$1.add(
                        const Duration(minutes: Salas.duracaoPadraoMin),
                      ),
                ultimo: i == itens.length - 1,
                destaque:
                    item.$2 is _ItemAgenda &&
                    !(item.$2 as _ItemAgenda).agendamento.status.encerrado,
                child: item.$2,
              ),
          ],
        );
      },
    );
  }
}

class _SeletorSemana extends StatelessWidget {
  const _SeletorSemana({required this.agendamentos});
  final List<Agendamento> agendamentos;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendaController>();
    final hoje = DateTime.now();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                Formatos.mesAno(ctrl.dia).toUpperCase(),
                style: TemaApp.corpo(
                  size: 13,
                  weight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: () => ctrl.mudarSemana(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              'Semana ${AgendaLogica.numeroDaSemana(ctrl.dia)}',
              style: TemaApp.corpo(size: 15, weight: FontWeight.w700),
            ),
            IconButton(
              tooltip: 'Próxima semana',
              onPressed: () => ctrl.mudarSemana(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final d in ctrl.diasDaSemana)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DiaChip(
                    dia: d,
                    selecionado: d.mesmoDia(ctrl.dia),
                    hoje: d.mesmoDia(hoje),
                    quantidade: agendamentos
                        .where(
                          (a) =>
                              a.inicio.mesmoDia(d) &&
                              a.status.ativo &&
                              (ctrl.profissionalId == null ||
                                  a.profissionalId == ctrl.profissionalId),
                        )
                        .length,
                    onTap: () => ctrl.selecionarDia(d),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DiaChip extends StatelessWidget {
  const _DiaChip({
    required this.dia,
    required this.selecionado,
    required this.hoje,
    required this.quantidade,
    required this.onTap,
  });
  final DateTime dia;
  final bool selecionado;
  final bool hoje;
  final int quantidade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? Colors.white : Cores.texto;
    final pontos = quantidade == 0 ? 0 : (quantidade > 6 ? 2 : 1);
    return Material(
      color: selecionado ? Cores.primaria : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: selecionado ? 3 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hoje && !selecionado ? Cores.teal : Cores.borda,
            ),
          ),
          child: Column(
            children: [
              Text(
                Formatos.diaSemanaCurto(dia),
                style: TemaApp.corpo(
                  size: 13,
                  color: selecionado ? Colors.white : Cores.textoSuave,
                ),
              ),
              Text('${dia.day}', style: TemaApp.titulo(size: 22, color: cor)),
              SizedBox(
                height: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pontos; i++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selecionado
                              ? Colors.white
                              : Cores.contornoSuave,
                        ),
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

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.rotulo,
    required this.ativo,
    required this.onTap,
    this.icone,
    this.detalhe,
    this.ponto = false,
  });
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;
  final IconData? icone;
  final String? detalhe;
  final bool ponto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: ativo ? Cores.primaria : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: ativo ? Cores.primaria : Cores.borda),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (icone != null) ...[
                Icon(
                  icone,
                  size: 18,
                  color: ativo ? Colors.white : Cores.texto,
                ),
                const SizedBox(width: 6),
              ],
              if (ponto) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ativo ? Colors.white : Cores.primaria,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                rotulo,
                style: TemaApp.corpo(
                  weight: FontWeight.w600,
                  color: ativo ? Colors.white : Cores.texto,
                ),
              ),
              if (detalhe != null) ...[
                const SizedBox(width: 4),
                Text(
                  detalhe!,
                  style: TemaApp.corpo(
                    size: 12,
                    color: ativo ? Colors.white70 : Cores.textoSuave,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({
    required this.rotulo,
    required this.n,
    required this.ativo,
    required this.onTap,
    this.cor = Cores.container,
  });
  final String rotulo;
  final int n;
  final bool ativo;
  final VoidCallback onTap;
  final Color cor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: cor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ativo ? Cores.primaria : Cores.borda,
              width: ativo ? 1.5 : 1,
            ),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$rotulo  ',
                  style: TemaApp.corpo(weight: FontWeight.w600),
                ),
                TextSpan(
                  text: '$n',
                  style: TemaApp.corpo(
                    weight: FontWeight.w700,
                    color: Cores.primaria,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CartaoSolicitacao extends StatelessWidget {
  const _CartaoSolicitacao({
    required this.solicitacao,
    required this.agora,
    required this.podeAvaliar,
  });
  final SolicitacaoReagendamento solicitacao;
  final DateTime agora;
  final bool podeAvaliar;

  @override
  Widget build(BuildContext context) {
    final s = solicitacao;
    void abrir() => context.go(Rotas.solicitacao(s.id));
    return Cartao(
      faixa: Cores.secundaria,
      elevado: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Cores.secundariaContainer,
                child: Icon(Icons.update, color: Cores.ardosia, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Sobrelinha(
                          'Ação necessária',
                          cor: Cores.primaria,
                        ),
                        Pilula.lilas(
                          Formatos.capitalizar(
                            Formatos.tempoDecorrido(s.criadoEm, agora),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pedido de troca de horário',
                      style: TemaApp.titulo(size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Bloco(
            child: Row(
              children: [
                Avatar(s.pacienteNome, tamanho: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.pacienteNome,
                        style: TemaApp.corpo(size: 15, weight: FontWeight.w700),
                      ),
                      Text(
                        'Resp: ${s.responsavelNome} • ${s.profissionalNome}',
                        style: TemaApp.corpo(size: 12, color: Cores.textoSuave),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ligar',
                  onPressed: () => avisarSimulado(context, 'Ligação'),
                  icon: const Icon(Icons.call_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Bloco(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_busy,
                            size: 14,
                            color: Cores.erroForte,
                          ),
                          const SizedBox(width: 4),
                          Text('Horário atual', style: TemaApp.corpo(size: 12)),
                        ],
                      ),
                      Text(
                        '${Formatos.diaMes(s.horarioAtual)} às ${Formatos.hora(s.horarioAtual)}',
                        style: TemaApp.corpo(
                          size: 15,
                          color: Cores.textoSuave,
                          tabular: true,
                        ).copyWith(decoration: TextDecoration.lineThrough),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_available,
                            size: 14,
                            color: Cores.primaria,
                          ),
                          const SizedBox(width: 4),
                          Text('Pretendido', style: TemaApp.corpo(size: 12)),
                        ],
                      ),
                      Text(
                        Formatos.diaHoraCurto(s.horarioPretendido),
                        style: TemaApp.corpo(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Cores.primaria,
                          tabular: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (podeAvaliar)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: abrir,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Ver pedido de troca'),
                  ),
                ),
                const SizedBox(width: 8),
                BotaoCinza(
                  rotulo: 'Detalhes',
                  icone: Icons.visibility_outlined,
                  onPressed: abrir,
                ),
              ],
            )
          else
            Text(
              'Aguardando avaliação da recepção.',
              style: TemaApp.corpo(color: Cores.textoSuave),
            ),
        ],
      ),
    );
  }
}

/// Coluna de horários + linha vertical à esquerda dos cartões.
class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({
    required this.inicio,
    required this.fim,
    required this.child,
    required this.ultimo,
    required this.destaque,
  });
  final DateTime inicio;
  final DateTime fim;
  final Widget child;
  final bool ultimo;
  final bool destaque;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 56,
          child: Column(
            children: [
              Text(
                Formatos.hora(inicio),
                style: TemaApp.corpo(
                  size: 16,
                  weight: FontWeight.w700,
                  color: destaque ? Cores.primaria : Cores.texto,
                  tabular: true,
                ),
              ),
              Text(
                Formatos.hora(fim),
                style: TemaApp.corpo(
                  size: 12,
                  color: Cores.textoSuave,
                  tabular: true,
                ),
              ),
              if (!ultimo)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: Cores.containerAlto,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class _ItemAgenda extends StatelessWidget {
  const _ItemAgenda({
    required this.agendamento,
    required this.troca,
    required this.usuario,
    required this.agora,
  });
  final Agendamento agendamento;
  final SolicitacaoReagendamento? troca;
  final Usuario usuario;
  final DateTime agora;

  bool get _clinico => Rotas.podeAcessar(usuario, Rotas.atendimento('x'));
  bool get _recepcao => usuario.perfil != Perfil.fono;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final est = estiloStatus(a.status);
    final repo = context.read<ClinicaRepositorio>();
    final idade = Formatos.idadeTexto(a.pacienteNascimento, agora);

    Widget pilulaStatus;
    if (troca != null) {
      pilulaStatus = const Pilula.lilas('Pediu troca', icone: Icons.sync_alt);
    } else if (a.whatsappConfirmado &&
        (a.status == StatusAgendamento.agendado ||
            a.status == StatusAgendamento.confirmado)) {
      pilulaStatus = const Pilula.sucesso(
        'Avisado no WhatsApp',
        icone: Icons.chat_outlined,
      );
    } else {
      pilulaStatus = Pilula(
        a.status.rotulo,
        fundo: est.fundo,
        cor: est.texto,
        icone: a.status == StatusAgendamento.emAtendimento ? null : est.icone,
        ponto: a.status == StatusAgendamento.emAtendimento,
      );
    }

    return Cartao(
      faixa: troca != null ? Cores.secundaria : est.faixa,
      padding: const EdgeInsets.all(14),
      cor: a.status.ativo ? Colors.white : Cores.containerBaixo,
      onTap: _clinico && a.status.ativo
          ? () => context.go(Rotas.atendimento(a.id))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: a.pacienteNome,
                            style:
                                TemaApp.corpo(
                                  size: 16,
                                  weight: FontWeight.w700,
                                ).copyWith(
                                  decoration: a.status.ativo
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                          ),
                          TextSpan(
                            text: '  ($idade)',
                            style: TemaApp.corpo(
                              size: 13,
                              color: Cores.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${a.profissionalNome} • ${a.sala}',
                      style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              pilulaStatus,
              if (_recepcao && !a.status.encerrado)
                PopupMenuButton<StatusAgendamento>(
                  tooltip: 'Mais ações',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (s) => repo.alterarStatus(a.id, s),
                  itemBuilder: (_) => [
                    if (a.status == StatusAgendamento.agendado)
                      const PopupMenuItem(
                        value: StatusAgendamento.confirmado,
                        child: Text('Marcar como confirmado'),
                      ),
                    const PopupMenuItem(
                      value: StatusAgendamento.faltou,
                      child: Text('Registrar falta'),
                    ),
                    const PopupMenuItem(
                      value: StatusAgendamento.cancelado,
                      child: Text('Cancelar atendimento'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          ..._rodape(context, repo),
        ],
      ),
    );
  }

  List<Widget> _rodape(BuildContext context, ClinicaRepositorio repo) {
    final a = agendamento;
    final t = troca;

    Widget linhaInfo(IconData icone, String texto, {Widget? fim}) => Row(
      children: [
        Icon(icone, size: 16, color: Cores.textoSuave),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
          ),
        ),
        ?fim,
      ],
    );

    if (t != null) {
      return [
        Bloco(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.arrow_forward, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pede ${Formatos.diaHoraCurto(t.horarioPretendido)}',
                  style: TemaApp.corpo(size: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: BotaoCinza(
                rotulo: 'Ver pedido',
                icone: Icons.edit_calendar_outlined,
                cor: Cores.secundariaContainer,
                onPressed: () => context.go(Rotas.solicitacao(t.id)),
              ),
            ),
            if (_recepcao && a.status != StatusAgendamento.naRecepcao) ...[
              const SizedBox(width: 8),
              BotaoCinza(
                rotulo: 'Check-in',
                onPressed: () => repo.registrarChegada(
                  a.id,
                  por: Formatos.primeiroNome(usuario.nome),
                ),
              ),
            ],
          ],
        ),
      ];
    }

    switch (a.status) {
      case StatusAgendamento.concluido:
        return [
          linhaInfo(
            a.evolucaoSalva ? Icons.fact_check_outlined : Icons.pending_actions,
            a.evolucaoSalva ? 'Evolução clínica salva' : 'Evolução pendente',
            fim: Text(
              'Sessão #${a.sessaoNumero}',
              style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
            ),
          ),
        ];
      case StatusAgendamento.emAtendimento:
        final desde = a.iniciadoEm ?? a.inicio;
        return [
          Row(
            children: [
              Expanded(
                child: linhaInfo(
                  Icons.door_front_door_outlined,
                  'Entrou às ${Formatos.hora(desde)} • '
                  '${agora.difference(desde).inMinutes.clamp(0, 999)} min decorridos',
                ),
              ),
              if (_clinico && usuario.id == a.profissionalId)
                FilledButton(
                  onPressed: () => context.go(Rotas.atendimento(a.id)),
                  child: const Text('Abrir'),
                )
              else if (_recepcao)
                BotaoCinza(
                  rotulo: 'Avisar\nProfissional',
                  onPressed: () =>
                      avisarSimulado(context, 'Aviso ao profissional'),
                ),
            ],
          ),
        ];
      case StatusAgendamento.naRecepcao:
        final chegada = a.chegadaEm ?? agora;
        return [
          linhaInfo(
            Icons.how_to_reg_outlined,
            'Chegada registrada ${Formatos.tempoDecorrido(chegada, agora)}'
            '${a.chegadaPor.isEmpty ? '' : ' por ${a.chegadaPor}'}',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await repo.iniciarAtendimento(a.id);
                    if (context.mounted && _clinico) {
                      context.go(Rotas.atendimento(a.id));
                    } else if (context.mounted) {
                      avisar(
                        context,
                        '${a.pacienteNome} chamado(a) para o consultório.',
                      );
                    }
                  },
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(
                    _clinico ? 'Iniciar atendimento' : 'Chamar paciente',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BotaoCinza(
                rotulo: 'Ficha',
                onPressed: () => _ficha(context, repo),
              ),
            ],
          ),
        ];
      case StatusAgendamento.agendado:
      case StatusAgendamento.confirmado:
        return [
          Row(
            children: [
              Expanded(
                child: linhaInfo(
                  a.tipo.contains('Audio')
                      ? Icons.hearing_outlined
                      : Icons.record_voice_over_outlined,
                  a.tipo,
                ),
              ),
              if (_recepcao)
                FilledButton.icon(
                  onPressed: () => repo.registrarChegada(
                    a.id,
                    por: Formatos.primeiroNome(usuario.nome),
                  ),
                  icon: const Icon(Icons.touch_app_outlined, size: 18),
                  label: const Text('Registrar chegada'),
                )
              else
                BotaoCinza(
                  rotulo: 'Ficha',
                  onPressed: () => _ficha(context, repo),
                ),
            ],
          ),
        ];
      case StatusAgendamento.faltou:
      case StatusAgendamento.cancelado:
        return [
          linhaInfo(
            Icons.info_outline,
            a.status == StatusAgendamento.faltou
                ? 'Paciente não compareceu'
                : 'Atendimento cancelado',
          ),
        ];
    }
  }

  void _ficha(BuildContext context, ClinicaRepositorio repo) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(agendamento.pacienteNome),
        content: Observar(
          stream: () => repo.paciente(agendamento.pacienteId),
          builder: (context, p) => p == null
              ? const Text('Ficha não encontrada.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nascimento: ${Formatos.data(p.dataNascimento)} '
                      '(${Formatos.idadeTexto(p.dataNascimento, agora)})',
                    ),
                    if (p.responsavelNome.isNotEmpty)
                      Text(
                        'Responsável: ${p.responsavelNome} (${p.parentesco})',
                      ),
                    if (p.telefone.isNotEmpty) Text('Telefone: ${p.telefone}'),
                    Text('Convênio: ${p.convenio}'),
                    Text('Área: ${p.area}'),
                    Text('Profissional: ${p.profissionalNome}'),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _HorarioLivre extends StatelessWidget {
  const _HorarioLivre({
    required this.inicio,
    required this.profissional,
    required this.onAgendar,
  });
  final DateTime inicio;
  final Usuario profissional;
  final VoidCallback onAgendar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Cores.containerBaixo,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Cores.borda),
    ),
    child: Row(
      children: [
        const IconeQuadrado(
          Icons.event_available,
          fundo: Cores.container,
          cor: Cores.textoSuave,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Horário livre', style: TemaApp.titulo(size: 15)),
              Text(
                profissional.nome,
                style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Cores.borda),
            backgroundColor: Colors.white,
            foregroundColor: Cores.texto,
          ),
          onPressed: onAgendar,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Agendar'),
        ),
      ],
    ),
  );
}
